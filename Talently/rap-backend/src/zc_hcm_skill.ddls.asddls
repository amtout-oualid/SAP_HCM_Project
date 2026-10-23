@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Skills - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Skill
  as projection on ZI_HCM_Skill
{
  key SkillId,
  EmployeeId,
  SkillName,
  Proficiency,
  CertName,
  IssuingBody,
  IssueDate,
  ExpiryDate,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
