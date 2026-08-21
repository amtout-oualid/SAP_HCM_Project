@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job Application - Interface'
define view entity ZI_HCM_Application
  as select from zhcm_applicatn
  association to parent ZI_HCM_JobOffer as _Offer
    on $projection.OfferId = _Offer.OfferId
  composition [0..*] of ZI_HCM_PipeProg as _Progress
  association [1] to ZI_HCM_Candidate as _Candidate
    on $projection.CandidateId = _Candidate.CandidateId
{
  key application_id           as ApplicationId,
      offer_id                 as OfferId,
      candidate_id             as CandidateId,
      resume_url               as ResumeUrl,
      cover_letter             as CoverLetter,
      @Semantics.systemDateTime.createdAt: true
      applied_at               as AppliedAt,
      current_step_order       as CurrentStepOrder,
      overall_status           as OverallStatus,
      ai_match_score           as AiMatchScore,
      notice_period            as NoticePeriod,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      salary_expectation       as SalaryExpectation,
      currency_code            as CurrencyCode,
      
      /* ADDED THESE TWO TO FIX ABAP ERRORS */
      rejection_reason         as RejectionReason,
      internal_notes           as InternalNotes,
      
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,

      _Offer,
      _Progress,
      _Candidate
}
