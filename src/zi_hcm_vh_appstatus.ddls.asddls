@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Application Status'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_AppStatus as select from zhcm_appstat {
  key status as Status,
  description as Description
}
