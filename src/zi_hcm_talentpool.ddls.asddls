@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Talent Pool'
define root view entity ZI_HCM_TALENTPOOL as select from zhcm_talntpool
{
  key pool_id as PoolId,
  candidate_id as CandidateId,
  original_offer_id as OriginalOfferId,
  candidate_name as CandidateName,
  candidate_email as CandidateEmail,
  resume_url as ResumeUrl,
  ai_score as AiScore,
  skills as Skills,
  status as Status,
  added_at as AddedAt,
  notes as Notes,
  rejection_reason as RejectionReason,
  last_changed_at as LastChangedAt
}
