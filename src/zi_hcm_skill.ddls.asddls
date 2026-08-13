@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Skill and Certification - Interface'
define view entity ZI_HCM_Skill
  as select from zhcm_skill
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key skill_id                as SkillId,
      employee_id              as EmployeeId,
      skill_name               as SkillName,
      proficiency              as Proficiency,
      cert_name               as CertName,
      issuing_body             as IssuingBody,
      issue_date               as IssueDate,
      expiry_date              as ExpiryDate,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
