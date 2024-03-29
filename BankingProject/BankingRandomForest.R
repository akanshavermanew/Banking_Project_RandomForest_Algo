#Banking project is build using Random forest and here we have to calculate and submit hard classes i.e cutoff also i.e KS
#Here ks = 0.3118435(KS score on test data. larger KS, better Model)

library(tidymodels)
library(visdat)
library(tidyr)
library(car)
library(pROC)
library(ggplot2)
library(tidyr)
library(ROCit)
library(vip)
library(rpart.plot)
library(DALEXtra)

setwd("F:/R study materials/Projects/BankingProject")
## ----
bt_train=read.csv("bank-full_train.csv",stringsAsFactors = FALSE)
bt_test=read.csv("bank-full_test.csv",stringsAsFactors = FALSE)

glimpse(bt_train)

vis_dat(bt_train)
unique(bt_train$education)

#Since we will be using random forest we need to convert data type of response (which is store in this case) to factor type using function as.factor. This is how randomforest differentiates from regression & classification.If we need to build a regression model then response variable should be kept numeric else factor for classification.


#for classification if we are using random forest algo then we need to convert the output variable into factor 
#and for linear regression we need to make it as numeric
#But here the output variable i.e. 'y' is already factor so there is no need to convert the outcome variable to factor5

#bt_train$y=as.factor(bt_train$y)

dp_pipe=recipe(y ~ .,data=bt_train) %>% 
  update_role(ID,new_role = "drop_vars") %>%
  update_role(job,marital,education,default,housing,loan,contact,month,poutcome  ,new_role="to_dummies") %>% 
  step_rm(has_role("drop_vars")) %>%
  step_unknown(has_role("to_dummies"),new_level="__missing__") %>% 
  step_other(has_role("to_dummies"),threshold =0.02,other="__other__") %>% 
  step_dummy(has_role("to_dummies")) %>% 
  step_impute_median(all_numeric(),-all_outcomes())

dp_pipe=prep(dp_pipe)

train=bake(dp_pipe,new_data = NULL)
test=bake(dp_pipe,new_data=bt_test)

vis_dat(train)
glimpse(train)

summary(dp_pipe)

#building random forest
rf_model = rand_forest(
  mtry = tune(),
  trees = tune(),
  min_n = tune()
) %>%
  set_mode("classification") %>%
  set_engine("ranger")

folds = vfold_cv(train, v = 5)

rf_grid = grid_regular(mtry(c(5,15)), trees(c(100,500)),     #for random forest passing some values is compulsory otherwise it will give error in decision tree the case was not like this
                       min_n(c(2,10)),levels = 3)

#IMP BELOW 2 STEPS
# c(5,19)  means start with 5 and go till 19
# mtry values should be <= features in your table
my_res=tune_grid(
  rf_model,
  y~.,
  resamples = folds,
  grid = rf_grid,
  metrics = metric_set(roc_auc),
  control = control_grid(verbose = TRUE)
)


autoplot(my_res)+theme_light()

fold_metrics=collect_metrics(my_res)    #grid search it will show table with parameters like mtry,tree_depth,etc (parameters of whatever model you are using

my_res %>% show_best()            #it will give best roc_auc value for our model from grid serch with all parameters of whatever model you are using like mtry,tree_depth,etc

#Finalizing the model
final_rf_fit=rf_model %>% 
  set_engine("ranger",importance='permutation') %>% 
  finalize_model(select_best(my_res,"roc_auc")) %>% 
  fit(y~.,data=train)

# variable importance 

final_rf_fit %>%
  vip(geom = "col", aesthetics = list(fill = "midnightblue", alpha = 0.8)) +
  scale_y_continuous(expand = c(0, 0))


# predicitons(first check cutoff and then do predictions on test data)

train_pred=predict(final_rf_fit,new_data = train,type="prob")%>% select(.pred_yes)

#do these 3 steps after finding cutoff
test_pred=predict(final_rf_fit,new_data = test,type="prob")%>% select(.pred_yes)
a=as.numeric(test_pred>0.3)
test_preds=ifelse(a==1,'Yes','No')

### finding cutoff for hard classes

train.score=train_pred$.pred_yes

real=train$y

# KS plot

rocit = ROCit::rocit(score = train.score, 
                     class = real) 

kplot=ROCit::ksplot(rocit)

# cutoff on the basis of KS

my_cutoff=kplot$`KS Cutoff`

## test hard classes 

test_hard_class=as.numeric(test_preds>my_cutoff)

#write csv
write.table(test_preds,"Akansha_Verma_P5_part2.csv",row.names=F,col.names='y')
getwd()
