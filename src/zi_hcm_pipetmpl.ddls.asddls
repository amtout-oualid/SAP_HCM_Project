@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pipeline Template Step - Interface'
define view entity ZI_HCM_PipeTmpl
  as select from zhcm_pipe_tmpl
  association to parent ZI_HCM_JobOffer as _Offer
    on $projection.OfferId = _Offer.OfferId
{
  key template_id             as TemplateId,
      offer_id                as OfferId,
      step_name               as StepName,
      step_order              as StepOrder,
      step_type               as StepType,
      step_desc               as StepDescription, 
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt,
       
      _Offer
}
