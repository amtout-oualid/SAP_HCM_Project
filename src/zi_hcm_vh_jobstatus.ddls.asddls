@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Job Status'
define view entity ZI_HCM_VH_JobStatus as select from zhcm_jobstat {
  key status as Status,
  description as Description
}
