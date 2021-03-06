

# Load packages.
packages <- c("downloader", "ggplot2", "reshape", "scales", "xlsx", "zoo")
packages <- lapply(packages, FUN = function(x) {
  if(!require(x, character.only = TRUE)) {
    install.packages(x)
    library(x, character.only = TRUE)
  }
})



# Set name of first data extract.
ps.share = "data/piketty.saez.2011.share.csv"
# Set name of second data extract.
ps.income = "data/piketty.saez.2011.income.csv"
# Set name of source dataset.
zip = "data/piketty.saez.2011.zip"

# Create ZIP archive.
if (!file.exists(zip)) {
  # Target data link.
  url = "http://elsa.berkeley.edu/~saez/TabFig2011prel.xls"
  # Target filename.
  xls = "data/piketty.saez.2011.xls"
  # Download source dataset.
  if (!file.exists(xls))
    download(url, xls, mode = "wb")

  # Import first data extract (income shares) from XLS source.
  data = read.xlsx(xls, sheetName = "Table A1",
                   startRow = 4, endRow = 104, colIndex = 1:7)
  # Remove empty line.
  data = data[-1, ] 
  # Save local copy.
  write.csv(data, ps.share, row.names = FALSE)

  # Import second example sheet from XLS source.
  data = read.xlsx(xls, sheetName = "Table_Incomegrowth", 
                   startRow = 1, endRow = 103, colIndex = c(10, 5, 3))
  # Remove empty line.
  data = data[-1, ]
  # Add years manually (little data bug).
  data = cbind(1913:2011, data)
  # Save local copy.
  write.csv(data, ps.income, row.names = FALSE)

  # Create ZIP with source and data extracts.
  zip(zip, files = c(xls, ps.share, ps.income))
  # Remove files (we will read from the ZIP).
  file.remove(xls, ps.share, ps.income)
}



# Read CSV file.
ps.share = read.csv(unz(zip, ps.share), stringsAsFactors = FALSE)
# Check result.
str(ps.share)



# Change variable names.
names(ps.share) <- c("Year", paste0("Top ", c(10, 5, 1, 0.5, 0.1, 0.01), "%"))
# Reshape to long format.
ps.share <- melt(ps.share, id = "Year", variable_name = "Fractile")
# Drop missing data.
ps.share <- na.omit(ps.share)
# Check result.
head(ps.share)



# Time series plot.
qplot(data = ps.share, x = Year, y = value / 100, color = Fractile, geom = "line") + 
  labs(y = NULL, x = NULL, title = "U.S. top income shares (%)") +
  geom_text(data = subset(ps.share, Year == 2011), aes(x = 2013, label = Fractile, hjust = 0)) +
  scale_x_continuous(lim = c(1911, 2031), breaks = seq(1910, 2010, by = 20)) +
  scale_y_continuous(labels = percent) +
  theme(legend.position = "none")



# Read CSV file.
ps.income = read.csv(unz(zip, ps.income))
# Check result.
str(ps.income)



# Change variable names.
names(ps.income) <- c("Year", "Top 10%", "Top 1%", "Bottom 90%")
# Reshape to long format.
ps.income <- melt(ps.income, id = "Year", variable_name = "Fractile")
# Drop missing data.
ps.income <- na.omit(ps.income)
# Check result.
head(ps.income)



# Plot in real dollar units.
qplot(data = ps.income, x = Year, y = value, color = Fractile, geom = "line") +
  geom_text(data = subset(ps.income, Year == 2011), 
            aes(x = 2013, label = Fractile, hjust = 0)) +
  scale_x_continuous(lim = c(1911, 2031), breaks = seq(1910, 2010, by = 20)) +
  scale_y_continuous(labels = dollar) +
  labs(y = NULL, x = NULL, title = "Real income growth in the United States") +
  theme(legend.position = "none")



# Plot in log10 dollar units.
qplot(data = ps.income, x = Year, y = value, color = Fractile, geom = "line") +
  geom_text(data = subset(ps.income, Year == 2011), 
            aes(x = 2013, label = Fractile, hjust = 0)) +
  scale_x_continuous(lim = c(1911, 2031), breaks = seq(1910, 2010, by = 20)) +
  scale_y_log10(labels = dollar) +
  labs(y = NULL, x = NULL, title = "Real income growth in the United States") +
  theme(legend.position = "none")



# Add lagged series.
ps.income <- ddply(ps.income, .(Fractile), transform,
                   lagged = c(NA, value[-length(value)]))
# Create growth rate.
ps.income$rate <- with(ps.income, (value / lagged) - 1)
# Plot real income growth rates.
qplot(data = ps.income, 
      ymin = 0, ymax = rate, x = Year, geom = "linerange") +
  geom_hline(y = 0, color = "gray") +
  aes(color = ifelse(rate > 0, "positive", "negative")) +
  scale_colour_manual("", values = c("positive" = "blue", "negative" = "red")) +
  scale_y_continuous(labels = percent) +
  facet_grid(Fractile ~ .) +
  labs(x = NULL, y = NULL, title = "Real income growth rate") +
  theme(legend.position = "none")



# Add differenced series.
ps.income <- ddply(ps.income, .(Fractile), transform,
                   Difference = c(NA, diff(value)))
# Plot real income changes.
qplot(data = ps.income, 
      ymin = 0, ymax = Difference, x = Year, geom = "linerange") +
  geom_hline(y = 0, color = "gray") +
  aes(color = ifelse(rate > 0, "positive", "negative")) +
  scale_colour_manual("", values = c("positive" = "blue", "negative" = "red")) +
  scale_y_continuous(labels = dollar) +
  facet_grid(Fractile ~ ., scale = "free_y") +
  labs(x = NULL, y = NULL, title = "Changes in real income") +
  theme(legend.position = "none")



# Subsetting to top 1% incomes.
ps_top1 <- subset(ps.income, Fractile=="Top 1%")
# Create a time series.
ps_top1 <- with(ps_top1, zoo(value, Year))
# Check result.
str(ps_top1)
# Detrend the series.
m <- lm(coredata(ps_top1) ~ index(ps_top1))
# Plot the residuals.
qplot(ymin = 0, ymax = resid(m), x = index(ps_top1), geom = "linerange") +
  aes(color = ifelse(resid(m) > 0, "positive", "negative")) +
  scale_color_manual("", values = c("positive" = "blue", "negative" = "red")) +
  scale_y_continuous(label = dollar) +
  labs(x = NULL, title = "Detrended series of top 1% income growth") +
  theme(legend.position = "none")


