@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Experience Level'
define view entity ZI_HCM_VH_ExpLevel as select from zhcm_explvl {
  key exp_level as ExperienceLevel,
  description as Description
}
