@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pipeline Progress - Interface'
define view entity ZI_HCM_PipeProg
  as select from zhcm_pipe_prog
  association to parent ZI_HCM_Application as _Application
    on $projection.ApplicationId = _Application.ApplicationId
  association [1..1] to ZI_HCM_JobOffer as _Offer
    on $projection.OfferId = _Offer.OfferId
{
  key progress_id             as ProgressId,
      application_id           as ApplicationId,
      _Application.OfferId     as OfferId,
      step_order              as StepOrder,
      step_name               as StepName,
      status                 as Status,
      score                  as Score,
      notes                  as Notes,
      completed_at             as CompletedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt,

      _Application,
      _Offer
}
