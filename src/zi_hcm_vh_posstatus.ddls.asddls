@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Position Status'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_PosStatus
  as select from zhcm_genstat
{
      @ObjectModel.text.element: ['Description']
  key status      as Status,
      description as Description
}
where
     status = 'V'
  or status = 'F'
  or status = 'Z'
