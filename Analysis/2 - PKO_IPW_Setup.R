############################################################################
###############------------PKO IPW/Matching Set Up-----------###############
############################################################################

pacman::p_load(
  "tidyverse", # Data Manipulation and Visualization
  "broom", # Converting Model Output to Data Frames
  "WeightIt", # IPW
  "MatchIt", # Matching
  "cobalt", # Assessing Balance
  "ggpubr", # Combining Plots Together
  install = FALSE
)

#######-------Inverse Probability Weighting-------#######
# Conflict-Level
# Generate Propensity Scores Manually to Investigate Extreme Propensity Scores
prop_pko_model <- glm(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                      family = binomial(link = "logit"),
                      data = merged)

merged_ipw <- augment_columns(prop_pko_model, merged,
                             type.predict = "response") %>%
  rename(propensity = .fitted) %>%
  # Filter Propensity Scores Less than 0.05 (There are None > 0.95)
  filter(propensity >= 0.05)

# Generate the Weights
pko_weights <- weightit(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                        data = merged,
                        estimand = "ATT",
                        method = "ps")

# Merge the Weights Into the Data Set
merged_ipw <- merged %>%
  mutate(ipw = pko_weights$weights)

# Post-Conflict Level

#######-------Mahalanobis Distance Matching-------#######
# Conflict-Level
merged_mmatch <- matchit(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                     data = merged,
                     method = "nearest",
                     estimand = "ATT",
                     distance = "mahalanobis",
                     replace = TRUE)

# Post-Conflict Level

#######-------Coarsened Exact Matching-------#######
# Conflict-Level
merged_cmatch <- matchit(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                     data = merged,
                     method = "cem",
                     estimand = "ATT")

# Post-Conflict Level

# Assess Balance (Conflict-Level)
bal.tab(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war, # Not Weighted/Matched
        data = merged,
        estimand = "ATT",
        thresholds = c(m = .05))

bal.tab(pko_weights, # IPW Weighted
        stats = c("m", "v"),
        thresholds = c(m = .05))

bal.tab(merged_mmatch, # NN Matched
        stats = c("m", "v"),
        thresholds = c(m = .05))

bal.tab(merged_cmatch, # CEM Matched
        stats = c("m", "v"),
        thresholds = c(m = .05))

# Assess Balance (Post-Conflict Level)

# Generate New Names for Confounders for Visualization (Conflict-Level)
v_names <- data.frame(old = c("lnatres", "lgdppc", "lpop", "lmilper", "civ_war"),
                      new = c("Natural Resources pc", 
                              "GDP pc", "Population", "Military Personnel pc",
                              "Civil War")
)

# Generate New Names for Confounders (Post-Conflict Level)

# Covariate Balance Plots (Conflict-Level)
cb_lplot <- love.plot(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                      data = merged, estimand = "ATT",
                      weights = list(w1 = get.w(pko_weights),
                                     w2 = get.w(merged_mmatch),
                                     w3 = get.w(merged_cmatch)),
                      abs = TRUE,
                      stars = "raw",
                      line = TRUE,
                      thresholds = c(m = .05),
                      var.order = "unadjusted",
                      var.names = v_names,
                      colors = c("#440154", "#2d708e", "#52c569", "#c2df23"),
                      sample.names = c("Original", "IPW", "NN Matching", "CEM")
                      ) +
  labs(caption = "* indicates the reporting of raw difference in means") +
  theme(plot.caption.position = "plot")

ggsave(
  "cb_lplot.png",
  width = 6,
  height = 4,
  path = "C:/Users/brian/Desktop/Peacebuilding Dissertation/PKO/Graphics"
)

# Covariate Balance Plots (Post-Conflict Level)

# Density and Bar Plots (Conflict-Level)

# GDP per capita
gdp_den <- bal.plot(pko ~ lgdppc, data = merged,
         weights = list(NN = merged_mmatch,
                        CEM = merged_cmatch,
                        IPW = pko_weights),
         var.name = "lgdppc", which = "both") +
  labs(title = "Distributional Balances for Covariates", x = "Log(GDP per capita)") +
  scale_fill_discrete(name = "PKO")

# Military Personnel per capita
milper_den <- bal.plot(pko ~ lmilper, data = merged,
                    weights = list(NN = merged_mmatch,
                                   CEM = merged_cmatch,
                                   IPW = pko_weights),
                    var.name = "lmilper", which = "both") +
  labs(title = "", y = "", x = "Log(Military Personnel per capita)") +
  scale_fill_discrete(name = "PKO") +
  theme(legend.position = "none") # Removing Legend for Combined Graphic

# Natural Resources per capita
natres_den <- bal.plot(pko ~ lnatres, data = merged,
                    weights = list(NN = merged_mmatch,
                                   CEM = merged_cmatch,
                                   IPW = pko_weights),
                    var.name = "lnatres", which = "both") +
  labs(title = "", y = "", x = "Log(Natural Resources per capita)") +
  scale_fill_discrete(name = "PKO") +
  theme(legend.position = "none")

# Population
pop_den <- bal.plot(pko ~ lpop, data = merged,
                    weights = list(NN = merged_mmatch,
                                   CEM = merged_cmatch,
                                   IPW = pko_weights),
                    var.name = "lpop", which = "both") +
  labs(title = "", y = "", x = "Population") +
  scale_fill_discrete(name = "PKO") +
  theme(legend.position = "none")

# Civil War
civ_bar <- bal.plot(pko ~ civ_war, data = merged,
                    weights = list(NN = merged_mmatch,
                                   CEM = merged_cmatch,
                                   IPW = pko_weights),
                    var.name = "civ_war", which = "both") +
  labs(title = "", y = "", x = "Civil War") +
  scale_fill_discrete(name = "PKO") +
  theme(legend.position = "none")

# Create the Combined Plot With a Customized Title

combined <- ggarrange(gdp_den, milper_den, natres_den, pop_den, civ_bar,
                      ncol = 1, nrow = 5)

ggsave(
  "comb_den_plots.png",
  width = 6,
  height = 8,
  path = "C:/Users/brian/Desktop/Peacebuilding Dissertation/PKO/Graphics"
)

# Density and Bar Plots (Post-Conflict Level)

# Create a K-S Love Plot (Conflict-Level)

ks_plot <- love.plot(pko ~ lnatres + lgdppc + lpop + lmilper + civ_war,
                     data = merged, estimand = "ATT",
                     stats = "ks.statistics",
                     weights = list(w1 = get.w(pko_weights),
                                    w2 = get.w(merged_mmatch),
                                    w3 = get.w(merged_cmatch)),
                     abs = TRUE,
                     line = TRUE,
                     thresholds = c(m = .05),
                     var.order = "unadjusted",
                     var.names = v_names,
                     colors = c("#440154", "#2d708e", "#52c569", "#c2df23"),
                     sample.names = c("Original", "IPW", "NN Matching", "CEM"))

ggsave(
  "ks_plot.png",
  width = 6,
  height = 4,
  path = "C:/Users/brian/Desktop/Peacebuilding Dissertation/PKO/Graphics"
)

# Create a K-S Love Plot (Post-Conflict Level)

# Convert Matches to Data Set
merged_mmatch <- match.data(merged_mmatch)
merged_cmatch <- match.data(merged_cmatch)

