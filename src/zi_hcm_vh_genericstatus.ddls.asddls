@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Generic Status'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_GenericStatus as select from zhcm_genstat {
  key status as Status,
  description as Description
}
