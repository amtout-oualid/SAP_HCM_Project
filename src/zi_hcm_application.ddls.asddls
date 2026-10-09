@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job Application - Interface'
define view entity ZI_HCM_Application
  as select from zhcm_applicatn
  association to parent ZI_HCM_JobOffer as _Offer
    on $projection.OfferId = _Offer.OfferId
  composition [0..*] of ZI_HCM_PipeProg as _Progress
  association [1] to ZI_HCM_Candidate as _Candidate
    on $projection.CandidateId = _Candidate.CandidateId
  association [0..1] to ZI_HCM_VH_AppStatus as _AppStatus
    on $projection.OverallStatus = _AppStatus.Status
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
      ai_recommendation        as AiRecommendation,
      ai_summary               as AiSummary,
      notice_period            as NoticePeriod,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      salary_expectation       as SalaryExpectation,
      currency_code            as CurrencyCode,

      rejection_reason         as RejectionReason,
      internal_notes           as InternalNotes,

      /* Status colors: 3 = green (accepted), 1 = red (rejected), 2 = yellow (in progress) */
      case overall_status
        when 'A' then 3
        when 'R' then 1
        else 2
      end as StatusCriticality,

      /* AI recommendation colors: 3 = hire, 2 = consider, 1 = do not hire, 0 = not evaluated */
      case ai_recommendation
        when 'STRONG_HIRE' then 3
        when 'HIRE'        then 3
        when 'CONSIDER'    then 2
        when 'DO_NOT_HIRE' then 1
        else 0
      end as AiCriticality,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at    as LocalLastChangedAt,

      _Offer,
      _Progress,
      _Candidate,
      _AppStatus
}
