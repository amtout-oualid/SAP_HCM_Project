@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Departments'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_Department
  as select distinct from zhcm_orgunit
{
      @EndUserText.label: 'Department'
  key cast( unit_name as abap.char(40) ) as Department
}
where
  status <> 'I'
