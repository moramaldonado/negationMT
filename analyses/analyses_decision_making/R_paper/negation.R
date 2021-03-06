
######################### NEGATION EXPERIMENT - ANALYSES ON SENTENCE VERIFICATION  ####################
###################################################################################################

## DATA EXTRACTION ####
getwd()
negation_info <- read.csv(file="data_R/negation_data/negation_info.csv", header=TRUE, sep=",")
negation_data <- read.csv(file="data_R/negation_data/negation_data_simple.csv", header=TRUE, sep=",")
negation_data_positions <- read.csv(file="data_R/negation_data/negation_data_positions.csv", header=TRUE, sep=",")

x <- paste0('x', sprintf("%03d", c(1:101)))
y <- paste0('y', sprintf("%03d", c(1:101)))


## SUBJECT and TRIAL EXCLUSION ####
###  Excluding not natives English speakers
natives <- subset(negation_info, grepl('en',negation_info$Language, ignore.case=TRUE))
not_natives <- subset(negation_info, !(Subject %in% natives$Subject))
negation_info<- subset(negation_info, !(Subject %in% not_natives$Subject))
negation_data <- subset(negation_data, !(Subject %in% not_natives$Subject))
negation_data_positions <- subset(negation_data_positions, !(Subject %in% not_natives$Subject))
rm(natives, not_natives)

### Excluding unaccurate trials
non_accurate_data <- subset (negation_data, Accuracy==FALSE)
print('percentage of innaccurate trials:')
print(nrow(non_accurate_data)/nrow(negation_data))
negation_data <- subset(negation_data, Accuracy==TRUE)
negation_data_positions <- subset(negation_data_positions, Accuracy==TRUE)

## OVERALL PERFORMANCE ####
normalized_positions.means.subject <- ddply(negation_data_positions, c("Polarity", "Time.Step", "Expected_response", "Subject"),
                                            function(negation_data_positions)c(X.Position.mean=mean(negation_data_positions$X.Position, na.rm=T), 
                                                                                 Y.Position.mean=mean(negation_data_positions$Y.Position, na.rm=T)))

normalized_positions.means.traj <- ddply(normalized_positions.means.subject, c("Polarity", "Time.Step", "Expected_response"),
                                         function(normalized_positions.means.subject)c(X.Position.mean=mean(normalized_positions.means.subject$X.Position.mean, na.rm=T), 
                                                                                       X.Position.se=se(normalized_positions.means.subject$X.Position.mean, na.rm=T),
                                                                                       Y.Position.mean=mean(normalized_positions.means.subject$Y.Position.mean, na.rm=T), 
                                                                                       Y.Position.se=se(normalized_positions.means.subject$Y.Position.mean, na.rm=T)))

ggplot(normalized_positions.means.traj, aes(x=X.Position.mean, y=Y.Position.mean, color=Polarity, group=Polarity)) +
  geom_point(alpha=.5) + 
  ggtitle('') +
  xlab('X Coordinate') +
  ylab('Y Coordinate') +
  geom_errorbarh(aes(xmin=X.Position.mean-X.Position.se, xmax=X.Position.mean+X.Position.se), alpha=.4) + 
  theme_minimal()+
  expand_limits(x=c(-1.5,1.5)) + 
  scale_colour_manual(values=c("#DB172A", "#1470A5"), 
                      name="Polarity",
                      breaks=c("N", "P"),
                      labels=c("Negative", "Positive"))+ 
  facet_grid(.~Expected_response) 

ggsave('negation-data-mean-trajectory.png', plot = last_plot(), scale = 1, dpi = 300, path='paper/R/fig', width = 7, height = 5)

## Dale and Duran Replication ####
### Analysis on X-coordinates flips
mydata <- negation_data
mydata$Expected_response <- factor(mydata$Expected_response)
mydata$Polarity <- factor(mydata$Polarity)
contrasts(mydata$Expected_response) <- c(-0.5, 0.5)
contrasts(mydata$Polarity) <- c(0.5, -0.5)
mydata$Interaction<-factor(contrasts(mydata$Polarity)[mydata$Polarity]*
                             contrasts(mydata$Expected_response)[mydata$Expected_response]) 
### Mean values
xflips.means.subj <- ddply(mydata, c("Polarity", "Expected_response", "Subject"),
                           function(mydata)c(mean=mean(mydata$X.flips, na.rm=T)))

xflips.means <- ddply(xflips.means.subj, c("Polarity", "Expected_response"),
                      function(xflips.means.subj)c(mean=mean(xflips.means.subj$mean, na.rm=T), se = se(xflips.means.subj$mean)))

### Main effects
control_model1.lda <- lmer(X.flips ~ Polarity + Expected_response + Interaction + (1+Polarity*Expected_response|Subject), data = mydata, REML=FALSE)

#Main Effect: Polarity (Affirmative vs. Negative)
m0.sentence.lda <- lmer(X.flips ~ Expected_response  +Interaction+ (1+Polarity*Expected_response|Subject), data = mydata, REML=FALSE) #the value of intercept is not exactly the same as the one in my aggregate function, why?
anova(control_model1.lda, m0.sentence.lda)

#Main Effect :Expected_response (True vs. False)
m0.response.lda <- lmer(X.flips ~ Polarity  + Interaction+ (1+Polarity*Expected_response|Subject), data = mydata, REML=FALSE) #the value of intercept is not exactly the same as the one in my aggregate function, why?
anova(control_model1.lda, m0.response.lda)

### Effect of Interaction
control_model2.lda <- lmer(X.flips ~ Polarity*Expected_response + (1+Polarity*Expected_response|Subject), data = mydata, REML=FALSE)
m0.interaction.lda <- lmer(X.flips~ Polarity+Expected_response+ (1+Polarity*Expected_response|Subject), data = mydata, REML=FALSE) #the value of intercept is not exactly the same as the one in my aggregate function, why?
anova(control_model2.lda, m0.interaction.lda)
















##CLASSIFIER PERFORMANCE ####
### Full LDA
load('LDA-Full.RData')
source("paper/R/norm_positions_LDA.R")

normalized_positions.new <- normalized_positions %>%
  dplyr::select(Subject, Item.number, Polarity, Response, one_of(all_data_columns))
normalized_positions.new_pca <- bind_cols(normalized_positions.new,
                                          as.data.frame(predict(m_pca, normalized_positions.new)[,1:n_pca]))
lda_measure.new.df <- data_frame(
  lda_measure=c(as.matrix(dplyr::select(normalized_positions.new_pca, starts_with("PC"))) %*% v_lda- b_lda),
  Subject = normalized_positions.new_pca$Subject, 
  Item.number = normalized_positions.new_pca$Item.number, 
  Polarity = normalized_positions.new_pca$Polarity, 
  Response = normalized_positions.new_pca$Response)

##Including the relevant lda_measure in the data
negation_data$Subject <- factor(negation_data$Subject)
negation_data$Response <- factor(negation_data$Response)
negation_data$Polarity <- factor(negation_data$Polarity)
negation_data <- dplyr::full_join(lda_measure.new.df, negation_data, by=c("Subject", "Item.number", "Polarity", "Response"))
negation_data_positions$Subject <- factor(negation_data_positions$Subject)
negation_data_positions <- dplyr::full_join(lda_measure.new.df, negation_data_positions, by=c("Subject", "Item.number", "Polarity"))


### Coords only LDA
load('LDA-Coords.RData')
normalized_positions.new <- normalized_positions %>%
  dplyr::select(Subject, Item.number, Polarity, Response, one_of(all_data_columns))
normalized_positions.new_pca <- bind_cols(normalized_positions.new,
                                          as.data.frame(predict(m_pca, normalized_positions.new)[,1:n_pca]))
lda_measure.new.df <- data_frame(
  lda_measure_coords=c(as.matrix(dplyr::select(normalized_positions.new_pca, starts_with("PC"))) %*% v_lda- b_lda),
  Subject = normalized_positions.new_pca$Subject, 
  Item.number = normalized_positions.new_pca$Item.number, 
  Polarity = normalized_positions.new_pca$Polarity, 
  Response = normalized_positions.new_pca$Response)
negation_data <- dplyr::full_join(lda_measure.new.df, negation_data, by=c("Subject", "Item.number", "Polarity", "Response"))
negation_data_positions <- dplyr::full_join(lda_measure.new.df, negation_data_positions, by=c("Subject", "Item.number", "Polarity"))


### Figures: mean and distribution 
Palette1 <- c("#DB172A", "#1470A5")
negation_data_true <- filter(negation_data, Response=='true')

plot_measure(negation_data_true, "lda_measure", "Polarity")
ggsave('OriginalLDA-negation.png', plot = last_plot(), scale = 1, dpi = 300, path='paper/R/fig', width = 7, height = 5)

plot_measure(negation_data_true, "lda_measure_coords", "Polarity")
ggsave('CoordsLDA-negation.png', plot = last_plot(), scale = 1, dpi = 300, path='paper/R/fig', width = 7, height = 5)


save(negation_data, negation_data_positions, file = "negation_data_processed.RData")



## OTHER MT MEASURES ####

### Max Deviation 
plot_measure(negation_data, 'MaxDeviation', 'Polarity')
ggsave('MD_negation.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### MaxLogRatio 
plot_measure(negation_data, 'MaxLogRatio', 'Polarity')
ggsave('MaxRatio_negation.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### AUC 
plot_measure(negation_data, 'AUC', 'Polarity')
ggsave('AUC_negation.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
#### X-coordinate flips
plot_measure(negation_data, 'X.flips', 'Polarity')
ggsave('Xflips_negation.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')
### Acceleration component
plot_measure(negation_data, 'Acc.flips', 'Polarity')
ggsave('Accflips_negation.png', plot = last_plot(), scale = 1, dpi = 300,width = 10, path='paper/R/fig')


## BASELINE ####
source("paper/R/baseline.R")


save(negation_data.true_aff, file = "baseline_negation_processed.RData")


### Mean Trajectory
normalized_positions.means.subject <- ddply(normalized_positions.plot_true_af, c("Class", "Time.Step", "Subject"),
                                            function(normalized_positions.plot_true_af)c(X.Position.mean=mean(normalized_positions.plot_true_af$X.Position, na.rm=T), 
                                                                                         Y.Position.mean=mean(normalized_positions.plot_true_af$Y.Position, na.rm=T)))
normalized_positions.means.traj <- ddply(normalized_positions.means.subject, c("Class", "Time.Step"),
                                         function(normalized_positions.means.subject)c(X.Position.mean=mean(normalized_positions.means.subject$X.Position.mean, na.rm=T), 
                                                                                       X.Position.se=se(normalized_positions.means.subject$X.Position.mean, na.rm=T),
                                                                                       Y.Position.mean=mean(normalized_positions.means.subject$Y.Position.mean, na.rm=T), 
                                                                                       Y.Position.se=se(normalized_positions.means.subject$Y.Position.mean, na.rm=T)))
palette_baseline <- c('#939393', '#2a2a2a')
levels(normalized_positions.means.traj$Class) <- c('Early', 'Late')
ggplot(normalized_positions.means.traj, aes(x=X.Position.mean, y=Y.Position.mean, color=Class, group=Class)) +
  geom_point(alpha=.7) + 
  ggtitle('') +
  xlab('X Coordinate') +
  ylab('Y Coordinate') +
  labs(color='Commitment')  +
  scale_colour_manual(values=palette_baseline) +
  geom_errorbarh(aes(xmin=X.Position.mean-X.Position.se, xmax=X.Position.mean+X.Position.se), alpha=.4) + 
  theme_minimal()+
  expand_limits(x=c(-1.5,1.5)) 
ggsave('TrajectoriesBaseline.png', plot = last_plot(), scale = 1, dpi = 300, path='paper/R/fig', width = 7, height = 5)

### LDA on baseline
levels(negation_data.true_aff$Class) <- c('Early', "Late")
mydata.agreggated <- ddply(negation_data.true_aff, c("Class", "Subject"),
                           function(negation_data.true_aff)(c(mean=mean(negation_data.true_aff$lda_measure, na.rm=T))))

mydata.agreggated.overall <- ddply(mydata.agreggated, c("Class"),
                                   function(mydata.agreggated)(c(LDA=mean(mydata.agreggated$mean, na.rm=T), 
                                                                 se= se(mydata.agreggated$mean, na.rm=T))))

density <-ggplot(negation_data.true_aff, aes(x=lda_measure, fill=Class, color=Class)) +
  geom_density(alpha=.5)+
  scale_colour_manual(values=palette_baseline) +  scale_fill_manual(values=palette_baseline) +
  theme_minimal() + theme(legend.position = "none")

density <- density + theme_minimal() + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
                                             panel.background = element_blank(), 
                                             axis.title.x=element_blank(),
                                             axis.text.x=element_blank(),
                                             legend.text = element_text(size = 14), 
                                             legend.title = element_text(size = 14), 
                                             axis.title = element_text(size = 13), 
                                             axis.text = element_text(size = 13)) + border() + theme(plot.margin = unit(c(0.3, 0, 0.3, 0.3), "cm"))

sp <- ggbarplot(mydata.agreggated.overall, y = "LDA", x = "Class", ylab= FALSE, 
                color = "Class", palette = palette_baseline, fill="Class",
                alpha = 0.6) +   geom_errorbar(aes(ymin=LDA-se, ymax=LDA+se), width=.1) + border()  + rotate() 

sp <- sp + theme(axis.title.y=element_blank(),
                 axis.text.y=element_blank(),
                 axis.ticks.y=element_blank(),
        legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13), 
        plot.margin = unit(c(0, 0.3, 0.3, 0.3), "cm"))
        

ggarrange(density, sp, 
          ncol = 1, nrow = 2,  align = "v", 
          widths = c(1, 1), heights = c(1,0.5),
          common.legend = TRUE)
ggsave('LDA-baseline.png', plot = last_plot(), scale = 1, dpi = 300, path='paper/R/fig', width = 7, height = 5)





## CROSS-VALIDATION ####

#Data frame
ns <- c(10,15,20,25,30,35,40,FALSE)

auc_lda <- data.frame (N10=c(1:1000), N15=c(1:1000), N20=c(1:1000), N25=c(1:1000), 
                       N30=c(1:1000), N35=c(1:1000), N40=c(1:1000), TOTAL = c(1:1000),
                       measure= 'lda')
permutation_lda <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_lda')

auc_lda_coords <- data.frame (N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000), N25 = c(1:1000), 
                              N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000),TOTAL = c(1:1000),
                              measure = 'lda_coords')
permutation_lda_coords <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_lda_coords')

auc_xflips <- data.frame (N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000),
                          N25 = c(1:1000), N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
                          measure = 'xflips')
permutation_xflips <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_xflips')

auc_maxdeviation <- data.frame (N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000),
                                N25 = c(1:1000), N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
                                measure = 'maxdeviation')
permutation_maxdeviation <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_maxdeviation')


auc_maxratio <- data.frame (N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000),
                            N25 = c(1:1000), N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
                            measure = 'maxratio')
permutation_maxratio <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_maxratio')

auc_accflips <- data.frame (N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000), N25 = c(1:1000),
                            N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
                            measure = 'accflips')
permutation_accflips <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_accflips')


auc_auc <- data.frame ( N10 = c(1:1000), N15 = c(1:1000), N20 = c(1:1000), N25 = c(1:1000),
                        N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
                        measure = 'AUC')
permutation_auc <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_auc')

auc_baseline <- data.frame (
  N10 = c(1:1000),N15 = c(1:1000),N20 = c(1:1000),N25 = c(1:1000),
  N30 = c(1:1000), N35 = c(1:1000), N40 = c(1:1000), TOTAL = c(1:1000),
  measure = 'baseline')
permutation_baseline <- data.frame (N10=0, N15=0, N20=0, N25=0, N30=0, N35=0, N40=0,TOTAL = 0, measure = 'permutation_baseline')




#LDA: cross validation

#Other MT measures and baseline

for (i in 1:length(ns)) { 
  
  #Include null hypothesis (labels shuffled in Random column)
  negation_data_true <- random.within(negation_data_true, "Polarity")
  negation_data.true_aff <- random.within(negation_data.true_aff, "Class")
  
  results_lda <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='lda_measure', label= 'Polarity', n=ns[i])
  results_lda.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='lda_measure', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_lda$t, variable='original'), data.frame(value=results_lda.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_lda[i]<- roc.te$auc 
  auc_lda[i]<- results_lda$t  
  
  results_lda_coords <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='lda_measure_coords', label= 'Polarity', n=ns[i])
  results_lda_coords.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='lda_measure_coords', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_lda_coords$t, variable='original'), data.frame(value=results_lda_coords.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_lda_coords[i]<- roc.te$auc 
  auc_lda_coords[i]<- results_lda_coords$t
  
  
  
  #XFlips
  results_xflips <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='X.flips', label= 'Polarity', n=ns[i])
  results_xflips.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='X.flips', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_xflips$t, variable='original'), data.frame(value=results_xflips.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_xflips[i]<- roc.te$auc 
  auc_xflips[i]<- results_xflips$t
  
  
  results_maxdeviation <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='MaxDeviation', label= 'Polarity', n=ns[i])
  results_maxdeviation.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='MaxDeviation', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_maxdeviation$t, variable='original'), data.frame(value=results_maxdeviation.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_maxdeviation[i]<- roc.te$auc 
  auc_maxdeviation[i]<- results_maxdeviation$t
  
  results_maxratio <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='MaxLogRatio', label= 'Polarity', n=ns[i])
  results_maxratio.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='MaxLogRatio', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_maxratio$t, variable='original'), data.frame(value=results_maxratio.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_maxratio[i]<- roc.te$auc 
  auc_maxratio[i]<- results_maxratio$t
  
  results_accflips <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='Acc.flips', label= 'Polarity', n=ns[i])
  results_accflips.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='Acc.flips', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_accflips$t, variable='original'), data.frame(value=results_accflips.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_accflips[i]<- roc.te$auc 
  auc_accflips[i]<- results_accflips$t
  
  results_auc <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='AUC', label= 'Polarity', n=ns[i])
  results_auc.random <- boot(data=negation_data_true, statistic=auc_roc, R=1000, score='AUC', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_auc$t, variable='original'), data.frame(value=results_auc.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_auc[i]<- roc.te$auc 
  auc_auc[i]<- results_auc$t
  
  results_baseline <- boot(data=negation_data.true_aff, statistic=auc_roc, R=1000, score='lda_measure', label= 'Class', n=ns[i])
  results_baseline.random <- boot(data=negation_data.true_aff, statistic=auc_roc, R=1000, score='lda_measure', label= 'Random', n=ns[i])
  data <- rbind(data.frame(value=results_baseline$t, variable='original'), data.frame(value=results_baseline.random$t, variable='null'))  
  roc.te <- roc(data$variable, data$value)
  permutation_baseline[i]<- roc.te$auc 
  auc_baseline[i]<- results_baseline$t
  
}














##Cross validation
auc_all <- rbind(auc_lda, auc_xflips, auc_maxdeviation, auc_lda_coords, auc_maxratio, auc_accflips, auc_auc, auc_baseline) 
auc_all_melt <- melt(auc_all, id="measure")
permutations <- rbind(permutation_lda, permutation_lda_coords, permutation_maxdeviation, permutation_maxratio, permutation_xflips, permutation_accflips,permutation_auc, permutation_baseline)
permutations <- melt(permutations, id="measure")
permutations$measure <- revalue(permutations$measure, c("permutation_lda"="Original LDA", "permutation_lda_coords"="Coords LDA", "permutation_maxdeviation"="Maximal Deviation",
                                                        "permutation_maxratio"="Maximal LogRatio", "permutation_baseline"="Baseline", "permutation_xflips"="X-coordinate flips" ,
                                                        "permutation_accflips"="AccFlips", "permutation_auc"= 'Area Under Curve Trajectory'))

auc_means <- ddply(auc_all_melt, c("measure", "variable"),
                   function(auc_all_melt){c(mean=mean(auc_all_melt$value, na.rm=T), se= se(auc_all_melt$value, na.rm=T))})

auc_means$measure <- revalue(auc_means$measure, c("lda"="Original LDA", "lda_coords"="Coords LDA", "maxdeviation"="Maximal Deviation",
                                                  "maxratio"="Maximal LogRatio", "baseline"="Baseline", "xflips"="X-coordinate flips" ,
                                                  "accflips"="AccFlips", "AUC"= 'Area Under Curve Trajectory'))

auc_power <- ddply(auc_all_melt, c("measure", "variable"),
                   function(auc_all_melt){power(auc_all_melt$value)})
auc_power$measure <- revalue(auc_power$measure, c("lda"="Original LDA", "lda_coords"="Coords LDA", "maxdeviation"="Maximal Deviation",
                             "maxratio"="Maximal LogRatio", "baseline"="Baseline", "xflips"="X-coordinate flips" ,
                             "accflips"="AccFlips", "AUC"= 'Area Under Curve Trajectory'))


##Figures
permutations <- subset(permutations, measure!='AccFlips')
auc_means <- subset(auc_means, measure!='AccFlips')
permutations$measure <- factor(permutations$measure)
auc_means$measure <- factor(auc_means$measure)

auc_means$point <- if_else(auc_means$measure=='Original LDA' | auc_means$measure=='Coords LDA', 'big','small')
permutations$point <- if_else(permutations$measure=='Original LDA' | permutations$measure=='Coords LDA', 'big','small')


p1 <- ggplot(data=subset(auc_means, measure=='Original LDA' |measure=='Coords LDA'), aes(x=variable, y=mean, group=measure, colour=measure)) +
  geom_line(alpha=.7) +
  geom_point(alpha=.5, size=2) +
  ylab('Mean AUC') +
  xlab('') +
  ylim(0.4, 1) +
  geom_errorbar(aes(ymin=mean-se, ymax=mean+se), width=.1)+
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier') + theme(legend.position = 'none') + 
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13))

p2 <- ggplot(data=subset(permutations, measure=='Original LDA' |measure=='Coords LDA'), aes(x=variable, y=value, group=measure, colour=measure)) +
  geom_line(alpha=.7) +
  geom_point(alpha=.5, size=2) +
  ylab('Separability (AUC)') +
  xlab('') +
  ylim(0.6, 1) +
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier')  + 
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13))

ggarrange(p1, p2, 
          ncol = 2, nrow = 1,  align = "hv", 
          widths = c(1, 1), heights = c(1,1), common.legend = TRUE, labels = c("A", "B"), legend='right')

ggsave('auc_permutation_negation_1.png', plot = last_plot(), scale = 1, dpi = 300,width = 14, height=8, path='paper/R/fig')


auc_means$measure = factor(auc_means$measure,levels(auc_means$measure)[c(1,4,3,5,2,6,7)])

p3 <- ggplot(data=auc_means, aes(x=variable, y=mean, group=measure, colour=measure)) +
  geom_line(aes(linetype=point), # Line type depends on cond
            size = 1) +
  geom_point(alpha=.5, size=2) +
  ylab('Mean AUC') +
  xlab(' ') +
  ylim(0.4, 1) +
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier') + theme(legend.position = 'none') + 
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13))



p4 <- ggplot(data=permutations, aes(x=variable, y=value, group=measure, colour=measure)) +
  geom_line(aes(linetype=point), # Line type depends on cond
            size = 1) +
  geom_point(alpha=.5, size=2) +
  ylab('Separability (AUC)') +
  xlab('') +
  ylim(0.6, 1) +
  scale_colour_manual(values=cbPalette) +
  theme_minimal() + labs(colour='Classifier')  + 
  theme(legend.text = element_text(size = 14), 
        legend.title = element_text(size = 14), 
        axis.title = element_text(size = 13), 
        axis.text = element_text(size = 13))

p4 <- p4 + guides(linetype=FALSE) 
p3 <- p3 + guides(linetype=FALSE) 

ggarrange(p3, p4, 
          ncol = 2, nrow = 1,  align = "hv", 
          widths = c(1, 1), heights = c(1,1), labels = c("A", "B"))

ggsave('auc_permutation_negation_2.png', plot = last_plot(), scale = 1, dpi = 300,width = 14, height=8, path='paper/R/fig')




