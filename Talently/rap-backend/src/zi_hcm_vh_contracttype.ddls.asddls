@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Contract Type'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_ContractType as select from zhcm_conttyp {
  key contract_type as ContractType,
  description as Description
}
