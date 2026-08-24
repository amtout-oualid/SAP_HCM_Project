@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Pipeline Step Types'
@Search.searchable: true
define view entity ZI_HCM_VH_StepType
  as select from zhcm_step_type
{
  @ObjectModel.text.element: ['Description']
  @Search.defaultSearchElement: true
  key step_type   as StepType,
  
  @Search.defaultSearchElement: true
  description     as Description
}
