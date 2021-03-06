
######################### VALIDATION EXPERIMENT - ANALYSES ON QUASI DECISIONS  ####################
###################################################################################################

## DATA EXTRACTION ####
getwd()
calibration_info <- read.csv(file="data_R/calibration_info.csv", header=TRUE, sep=",")
calibration_data <- read.csv(file="data_R/calibration_data_simple.csv", header=TRUE, sep=",")
calibration_data_positions <- read.csv(file="data_R/calibration_data_positions.csv", header=TRUE, sep=",")

x <- paste0('x', sprintf("%03d", c(1:101)))
y <- paste0('y', sprintf("%03d", c(1:101)))

## SUBJECT and TRIAL EXCLUSION ####
### Subjects who didn't use mouse
yes_mouse <- subset(calibration_info, grepl('mouse',calibration_info$Clicker, ignore.case=TRUE))
calibration_info <- subset(calibration_info, (Subject %in% yes_mouse$Subject))
calibration_data <- subset(calibration_data, (Subject %in% yes_mouse$Subject))
calibration_data_positions <- subset(calibration_data_positions, (Subject %in% yes_mouse$Subject))

### EXCLUDING inaccurate trials
innacurate_data <- subset (calibration_data, Accuracy==FALSE)
print('percentage of innacurate trials:')
print(nrow(innacurate_data)/nrow(calibration_data))
calibration_data <- subset(calibration_data, Accuracy==TRUE)
calibration_data_positions <- subset(calibration_data_positions, Accuracy==TRUE)

calibration_data$Subject <- factor(calibration_data$Subject)
calibration_data_positions$Subject <- factor(calibration_data_positions$Subject)

## OVERALL PERFORMANCE ####
### Mean trajectories
calibration_data_positions_subject.means <- ddply(calibration_data_positions, c("PointChange", "Time.Step", "Subject"),
                                            function(calibration_data_positions)c(X.Position.mean=mean(calibration_data_positions$X.Position, na.rm=T), 
                                                                                 Y.Position.mean=mean(calibration_data_positions$Y.Position, na.rm=T)))

calibration_data_positions_overall.means <- ddply(calibration_data_positions_subject.means, c("PointChange", "Time.Step"),
                                         function(calibration_data_positions_subject.means)c(X.Position.mean=mean(calibration_data_positions_subject.means$X.Position, na.rm=T), 
                                                                                       X.Position.se=se(calibration_data_positions_subject.means$X.Position, na.rm=T),
                                                                                       Y.Position.mean=mean(calibration_data_positions_subject.means$Y.Position, na.rm=T), 
                                                                                       Y.Position.se=se(calibration_data_positions_subject.means$Y.Position, na.rm=T)))
calibration_data_positions_overall.means$PointChange <- factor(calibration_data_positions_overall.means$PointChange)

### Figure
ggplot(calibration_data_positions_overall.means, aes(x=X.Position.mean, y=Y.Position.mean, color=PointChange, group=PointChange)) + 
  geom_point(alpha=.4, size=1) + 
  ggtitle('')+
  xlab('X Coordinate') +
  ylab('Y Coordinate') +
  geom_errorbarh(aes(xmin=X.Position.mean-X.Position.se, xmax=X.Position.mean+X.Position.se), alpha=0.3) + 
  theme_minimal() +
  expand_limits(x=c(-1.5,1.5)) + 
  scale_colour_manual(values=myPalette,
                      name="Decision",
                      breaks=c("0", "0.4", "0.7", "0.9"),
                      labels=c("Straight", "Early (y=0.4)", "Middle (y=0.7)", "Late (y=0.9)")) +
  theme(legend.position='right')
ggsave('mean-trajectories-validation.png', plot = last_plot(), scale = 1, dpi = 300, width = 6, height = 5,  path='paper/R/fig')

## LDA FOR CLASSIFICATION ####

### Applying the LDA to validation data
source("R_scripts/calibration/LDA.R")
LDA_training.coord.dist(calibration_data)
save(m_pca, v_lda, b_lda, n_pca, all_data_columns, file="LDA-Full.RData")
calibration_data <- dplyr::full_join(lda_measure.df, calibration_data, by=c("Subject", "Item.number", "Expected_response"))
calibration_data_positions <- dplyr::full_join(lda_measure.df, calibration_data_positions, by=c("Subject", "Item.number", "Expected_response"))

save(calibration_data, calibration_data_positions, file="vvvvalidation.RData")

Palette1 <- c("#1470A5", "#DB172A")

### Figure: Mean and distribution of LDA measure

plot_measure(calibration_data, 'lda_measure_full', 'Decision')
ggsave('lda_distribution_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 7, path='paper/R/fig')

## OTHER MOUSE TRACKING MEASURES: Distribution and means ####
### Max Deviation 
plot_measure(calibration_data, 'MaxDeviation', 'Decision')
ggsave('MD_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### MaxLogRatio 
plot_measure(calibration_data, 'MaxLogRatio', 'Decision')
ggsave('MaxRatio_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### AUC 
plot_measure(calibration_data, 'AUC', 'Decision')
ggsave('AUC_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
#### X-coordinate flips
plot_measure(calibration_data, 'X.flips', 'Decision')
ggsave('Xflips_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### Acceleration component
plot_measure(calibration_data, 'Acc.flips', 'Decision')
ggsave('AC_calibration.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')


# CLASSIFIER PERFORMANCE ####
#### Bins for cross valiation
calibration_data$id <- 1:nrow(calibration_data)
bins_crossvalidation(calibration_data,'deviated','straight')

#### Data frame to save all the AUCs values
auc.bins <- data.frame(bins = c(1:10),
                       lda.full=c(1:10),
                       lda.vel.acc=c(1:10),
                       lda.coord.vel=c(1:10), 
                       lda.vel = c(1:10),
                       lda.acc=c(1:10), 
                       lda.coord=c(1:10),
                       logratio=c(1:10), 
                       xflips=c(1:10), 
                       maxdeviation=c(1:10),
                       accflips=c(1:10), 
                       topline=c(1:10))

# Data frame for iteration of different bins (for baseline)
iterations = 10000
random_classifier.df <- data.frame(matrix(ncol=iterations, nrow=10))

#### Cross-validation for LDA classifier vs. baseline vs. topline
for (b in 1: length(bins)) {
  
  calibrationTrain <- subset(calibration_data, !(id %in% bins[[b]]$id))
  calibrationTest <- subset(calibration_data, id %in% bins[[b]]$id)
  
  ## FULL LDA
  LDA_training.coord.dist(calibrationTrain)
  LDA_test.coord.dist(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure 
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.full[b] <- lda.roc.te$auc
  
  ## TOPLINE
  calibrationTrain <- subset(calibration_data, !(id %in% bins[[b]]$id))
  calibrationTest <- subset(calibration_data, !(id %in% bins[[b]]$id)) #NB: Same data for training and testing
  
  ###  TRAINING + TEST
  LDA_training.coord.dist(calibrationTrain)
  LDA_test.coord.dist(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  lda.score.te <- lda_measure_te.df$lda_measure 
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.topline <- roc(lda.label.te, lda.score.te)
  lda.topline.auc <- lda.roc.topline$auc
  
  auc.bins$topline[b] <- lda.roc.topline$auc
  
  ##BASELINE
  calibrationTrain <- subset(calibration_data, !(id %in% bins[[b]]$id))
  calibrationTest <- subset(calibration_data, id %in% bins[[b]]$id)
  random_classifier(calibrationTrain, calibrationTest, iterations)
  
  ###  TRAINING + TEST
  for (i in 1:iterations){      
    point1 <- if_else(i==1, 1, (length(calibrationTest$Polarity)*(i-1))+1)
    point2 <- length(calibrationTest$Polarity)*i
    #print(c(point1, point2))
    random_classifier.iteration <- my[point1:point2]
    
    #score <- calibrationTest$random_classifier#predictor 
    score <- random_classifier.iteration #predictor 
    label <- factor(calibrationTest$Polarity) #response
    roc <- roc(label, score)
    random_classifier.df[b,i] <- roc$auc
  }
}

#### Cross-validation for LDA with different predictors
for (b in 1: length(bins)) {
  calibrationTrain <- subset(calibration_data, !(id %in% bins[[b]]$id))
  calibrationTest <- subset(calibration_data, id %in% bins[[b]]$id)
  
  ## LDA *only* with Coordinates
  ###  TRAINING + TEST
  LDA_training.coord(calibrationTrain)
  LDA_test.coord(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure 
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.coord[b] <- lda.roc.te$auc
  
  ## LDA with only Velocity
  ###  TRAINING + TEST
  LDA_training.vel(calibrationTrain)
  LDA_test.vel(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.vel[b] <- lda.roc.te$auc
  
  ## LDA with  Velocity, Acceleration
  ###  TRAINING + TEST
  LDA_training.vel.acc(calibrationTrain)
  LDA_test.vel.acc(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.vel.acc[b] <- lda.roc.te$auc
  
  
  ## LDA with Coordinates, Velocity
  ###  TRAINING + TEST
  LDA_training.coord.vel(calibrationTrain)
  LDA_test.coord.vel(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.coord.vel[b] <- lda.roc.te$auc
  
  ## LDA with **only** with Acceleration
  ###  TRAINING + TEST
  LDA_training.dist.acc(calibrationTrain)
  LDA_test.dist.acc(calibrationTest, v_lda, b_lda, m_pca, all_data_columns, n_pca)
  
  #ROC and AUC
  lda.score.te <- lda_measure_te.df$lda_measure
  lda.label.te <- lda_measure_te.df$Deviation
  lda.roc.te <- roc(lda.label.te, lda.score.te)
  auc.bins$lda.acc[b] <- lda.roc.te$auc
  
}

#### Cross-validation for other commonly used MT measures  
for (b in 1: length(bins)) {
  calibrationTrain <- subset(calibration_data, !(id %in% bins[[b]]$id))
  calibrationTest <- subset(calibration_data, id %in% bins[[b]]$id)
  
  #AccFlips
  accflips.score.te <- calibrationTest$Acc.flips 
  accflips.label.te <- factor(calibrationTest$Polarity)
  accflips.roc.te <- roc(accflips.label.te, accflips.score.te)
  auc.bins$accflips[b] <- accflips.roc.te$auc
  
  #MaxLogRatio
  maxlogratio.score.te <- calibrationTest$MaxLogRatio 
  maxlogratio.label.te <- factor(calibrationTest$Polarity)
  maxlogratio.roc.te <- roc(maxlogratio.label.te, maxlogratio.score.te)
  auc.bins$logratio[b] <- maxlogratio.roc.te$auc
  
  #XFlips
  xflips.score.te <- calibrationTest$X.flips 
  xflips.label.te <- factor(calibrationTest$Polarity)
  xflips.roc.te <- roc(xflips.label.te, xflips.score.te)
  auc.bins$xflips[b] <- xflips.roc.te$auc
  
  #MaxDeviation
  maxdeviation.score.te <- calibrationTest$MaxDeviation 
  maxdeviation.label.te <- factor(calibrationTest$Polarity)
  maxdeviation.roc.te <- roc(maxdeviation.label.te,maxdeviation.score.te)
  auc.bins$maxdeviation[b] <- maxdeviation.roc.te$auc
  
  #AUC
  auc.score.te <- calibrationTest$AUC 
  auc.label.te <- factor(calibrationTest$Polarity)
  auc.roc.te <- roc(maxdeviation.label.te,auc.score.te)
  auc.bins$auc[b] <- auc.roc.te$auc
  
}

### Organizing cross-validation data
auc.bins$random_classifier <- rowMeans(random_classifier.df)
auc.bins_change <- melt(auc.bins, id=('bins'))
auc.bins_change$bins <- factor(auc.bins_change$bins)
auc.bins_change$variable<- factor(auc.bins_change$variable )

auc.bins_change$variable <- revalue(auc.bins_change$variable, c("lda.full"="Original LDA", "maxdeviation"="Maximal Deviation",
                                                                "lda.vel.acc" = "LDA Vel,Acc",   "lda.coord.vel" = "LDA Coords,Vel", 
                                                                "lda.vel" = "LDA Vel", "lda.acc" = "LDA Acc", "lda.coord" = "LDA Coords",
                                                  "logratio"="Maximal LogRatio", "random_classifier"="Baseline", "xflips"="X-coordinate flips" ,
                                                  "accflips"="AccFlips", "auc"= 'Area Under Trajectory', "topline"="Topline"))


### PERMUTATION TEST  (Tables 3 and 4) ####
auc.means <- aggregate(value~variable, data=auc.bins_change, mean)
auc.means <- cast(auc.means, .~variable)
auc.pvalues <- data.frame(matrix(ncol=length(levels(auc.bins_change$variable))-1, nrow = 2))

row.names(auc.pvalues) <- c('pvalue', 'tvalue')
len <- length(levels(auc.bins_change$variable))-1
colnames(auc.pvalues) <-  levels(auc.bins_change$variable)[2:len]

diff_mean <- function(y, tr, group1, group2) {
  mean(y[tr == group1]) - mean(y[tr == group2])
}

ITERATIONS <- 100
for (l in 1:len)
{
  baseline <- 'lda.full'
  comparison <- levels(auc.bins_change$variable)[l+1]
  print(comparison)
  auc.bins_subset <- subset(auc.bins_change,variable %in% c(baseline, comparison))
  tr <- factor(auc.bins_subset$variable)
  y <- auc.bins_subset$value
  #Mean differences
  diff_original <- diff_mean(y, tr, baseline, comparison)
  dist <- replicate(ITERATIONS, diff_mean(y, sample(tr, length(tr), FALSE),  baseline, comparison))
  p.value <- sum(dist > diff_original)/ITERATIONS  # one-tailed test
  
  #Save in DF
  auc.pvalues[1,l] <- p.value
  auc.pvalues[2,l] <- diff_original
  
}

rm(auc.bins_subset)
save(auc.pvalues, auc.means, file="Validation-ttest.RData")







### FIGURES ####
# Plotting mean AUC values
auc.bins_change$point <- if_else(auc.bins_change$variable=='Original LDA' |auc.bins_change$variable=='Baseline' | auc.bins_change$variable=='Topline', 'big','small')
auc.bins_change$variable = factor(auc.bins_change$variable,levels(auc.bins_change$variable)[c(1,11,13,2:6,12,7,8:10 )])

p1 <- ggplot(data=subset(auc.bins_change, variable=='Original LDA' |variable=='Baseline' | variable=='Topline' ), aes(x=bins, y=value, group=variable, colour=variable)) +
  geom_line(alpha=.7) +
  geom_point(alpha=.5, size=1) +
  ylab('Mean AUC') +
  xlab('') +
  ylim(0.4, 1) +
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier') + 
  theme(legend.position = 'none') + 
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13))

p2 <- ggplot(data=subset(auc.bins_change, variable %in% c("Original LDA", "LDA Vel,Acc", "LDA Coords,Vel", "LDA Vel", "LDA Acc", "LDA Coords", "Topline" , "Baseline")), aes(x=bins, y=value, group=variable, colour=variable)) +
  #p2 <-  ggplot(data=subset(auc.bins_change, variable %in% c("LDA Vel,Acc", "LDA Coords,Vel", "LDA Vel", "LDA Acc", "LDA Coords")), aes(x=bins, y=value, group=variable, colour=variable)) +
  geom_line(aes(linetype=point), # Line type depends on cond
          size = 1, alpha=.7,  position=position_jitter(w=0, h=0.015)) +
  #geom_point(size=2) +
  ylab('Mean AUC') +
  xlab(' ') +
  ylim(0.4, 1) +
 scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier') + theme(legend.position = 'right') 

p2 <- p2 + guides(linetype=FALSE) +
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title.x = element_text(size = 13), 
        axis.text.x = element_text(size = 13),
        axis.title.y=element_blank(),
        axis.text.y=element_blank())

ggarrange(p1, p2, 
          ncol = 2, nrow = 1,  align = "hv", 
          widths = c(0.5, 1), heights = c(1,1), common.legend = FALSE, labels = c("A", "B"))

# Figure 6
ggsave('auc_calibration_1.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')


p3 <- ggplot(data=subset(auc.bins_change, variable %in% c("Original LDA", "Maximal LogRatio", "X-coordinate flips","Maximal Deviation", "AccFlips", "Topline" , "Baseline", "Area Under Trajectory")), aes(x=bins, y=value, group=variable, colour=variable)) +
  geom_line(aes(linetype=point), # Line type depends on cond
            size = 1, alpha=.8) +
  ylab('Mean AUC') +
  xlab('') +
  ylim(0.4, 1) +
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier') + theme(legend.position = 'right') 

p3 <- p3 + guides(linetype=FALSE) +
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title.x = element_text(size = 13), 
        axis.text.x = element_text(size = 13),
        axis.title.y=element_blank(),
        axis.text.y=element_blank())

ggarrange(p1, p3, 
          ncol = 2, nrow = 1,  align = "hv", 
          widths = c(0.5, 1), heights = c(1,1), common.legend = FALSE, labels = c("A", "B"))

#Figure 9
ggsave('auc_calibration_2.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')







