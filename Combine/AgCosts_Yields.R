library(dplyr)
library(ineq)
library(ggplot2)
library(lme4)
library(lmerTest)
detach("package:raster", unload=TRUE)

setwd('../Ag')

pg_conf <- read.csv('../rds_settings', stringsAsFactors=FALSE)

con <- src_postgres(dbname='vitalsigns', host=pg_conf$host,
                      user=pg_conf$user, password=pg_conf$pass,
                      port=pg_conf$port)


##Get Maize Yields

#  agric_crops_by_field
#    ag4a_21 - What was the total value of seeds purchased?

allvars <- tbl(con, 'flagging__agric_crops_by_field') %>%
  select(Country, landscape_no,  crop_name, hh_refno, field_no, Season, Round,
         ag4a_15, ag4a_21, ag4a_08) %>%
  data.frame

allvars$Yield <- allvars$ag4a_15
allvars$Yield_PerArea <- allvars$ag4a_15/allvars$ag4a_08


#  agric_field_details
#    ag3a_32 What was the total value of [FERTILIZER] purchased?
#    ag3a_61 What was the total value of this pesticides/ herbicides purchased?
#    ag3a_22 What was the total value of organic fertilizer purchased?

inc7 <- tbl(con, 'flagging__agric_field_details') %>%
  select(Country, landscape_no, hh_refno, field_no, Season, Round, ag3a_32, ag3a_61, ag3a_22) %>%
  data.frame

allvars <- merge(allvars, inc7, all.x=F, all.y=F)

###################
##Results
###################


allvars$Investment <- rowSums(allvars[ , c("ag4a_21", "ag3a_32", "ag3a_61", "ag3a_22")], na.rm=T)

allvars <- merge(allvars, data.frame(Country = c("TZA", "RWA", "UGA"), USD=c(2230.5, 826, 3589)))

allvars$Investment <- allvars$Investment/allvars$USD

ggplot(allvars %>% filter(Investment > 0 & Country =='RWA'), aes(x=log(Investment), y=log(Yield))) + geom_point(aes(color=Crop.name)) +
  geom_smooth(method = "lm", se = FALSE)


agvalue <- read.csv('../../vitalsigns-analysis/ValueofNature/AgValue_Household.csv')

yield_input <- allvars %>% group_by(Country, Landscape.., Household.ID, USD) %>%
  summarize(Investment = sum(Investment, na.rm=T)) %>% merge(agvalue)

landscape_df <- data.frame(Landscape..=c('L07', 'L04', 'L03', 'L01', 'L06', 'L02'),
                           Location=c('Other Landscape', 'Other Landscape', 'Other Landscape',
                                      'Other Landscape', 'Landscape A', 'Landscape B'))

yield_input <- merge(yield_input, landscape_df)

breakfun <- function(x){
  signif(exp(x), digits=2)
}

ys <- yield_input %>% filter(Investment > 0)

ggplot(ys %>% filter(Country=='RWA'), aes(x=log(Investment), y=log(Crops/USD))) + 
  geom_point(aes(color=Location)) +
  geom_smooth(method='lm', fullrange=TRUE, se=F, color="black") + theme_bw() + 
  xlab("Value of Investment in Agriculture (USD)") + ylab("Value of Production of Annual Crops (USD)") + 
  scale_x_continuous(labels = breakfun) +
  scale_y_continuous(labels = breakfun)

ggplot(ys, aes(x=log(Investment), y=log(Crops/USD))) + 
  geom_point(aes(color=Location, alpha=ifelse(ys$Location=='Muhanga', 1, .4))) + guides(alpha=FALSE) +
  geom_smooth(method='lm', fullrange=TRUE, se = F, color="black") + theme_bw() + 
  xlab("Value of Investment in Agriculture (USD)") + ylab("Value of Production of Annual Crops (USD)") + 
  scale_x_continuous(labels = breakfun) +
  scale_y_continuous(labels = breakfun)

ls_m <- yield_input %>% group_by(Country, Landscape.., Location, USD) %>%
  summarize(Investment = mean(Investment, na.rm=T),
            Crops = mean(Crops, na.rm=T))

ggplot(ls_m %>% filter(Country=='RWA'), aes(x=Investment, y=Crops/USD)) + 
  geom_smooth(method='lm', fullrange=TRUE, se=F, color="gray") + 
  theme_bw() + 
  geom_point(aes(color=Location), size=2) +
  scale_color_manual(values=c('#669933', '#c04420', '#FFCC33')) +  
  xlab("Value of Investment in Agriculture (USD)") + 
  ylab("Value of Production of Annual Crops (USD)") + 
  theme(legend.position = c(0.8, 0.16))
ggsave('D://Documents and Settings/mcooper/Desktop/Images For Presentation/Degradation.png')


#VS RED #c04420
#VS Yellow #FFCC33
                             #VS Blue #66CCFF
                             #VS Green #669933
                             
                             #VS Light Green  #A4D65E
                             #VS Orange Red  #FF6C2F
                             #VS Orange   #F68D2E
                             
                             #purple #66CC33
                             #navy #000080



ggplot(allvars %>% filter(Crop.name=='Cassava' & Investment == 0)) + geom_histogram(aes(x=Yield_PerArea, fill=paste0(Country, Landscape..)), bins=10)

######################
#Eplot
######################

hh_id <- tbl(con, 'household_ref') %>% data.frame %>%
  select(Country = country, Landscape.. = landscape_no, Eplot.. = eplot_no, Household.ID=id)

intensification <- read.csv('../../vs-indicators-calc/Ag/AgIntensification.Field.csv')
intensification$survey_uuid <- NULL

biodiversity <- read.csv('../../vitalsigns-analysis/TreeBiodiversity/Biodiversity.Eplot.csv')
biodiversity$Eplot.. <- substr(biodiversity$Eplot.. + 1000, 2, 4)


biodiversity_hh <- merge(hh_id, biodiversity)

bio_hh_ag <- merge(biodiversity_hh, intensification)

bio_hh_ag_y <- merge(bio_hh_ag, allvars)


landscape <- bio_hh_ag_y %>% group_by(Country, Landscape..) %>% summarize(bio=mean(biodiversity), fert=mean(pct_fields_inorganic_fert, na.rm=T))

ggplot(landscape) + geom_point(aes(x=bio, y=fert, col=Country))

lmer(Yield_PerArea ~ biodiversity + pesticide + herbicide + fungicide + pct_buy_seed + (1|Country) + (1|Landscape..) + Investment, data=bio_hh_ag_y[bio_hh_ag_y$Crop.name=='Beans', ]) %>% summary

t <- read.csv('../../vs-indicators-calc/Ag/AgIntensification.csv')
