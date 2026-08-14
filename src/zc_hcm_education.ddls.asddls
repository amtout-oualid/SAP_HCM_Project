@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Education - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Education
  as projection on ZI_HCM_Education
{
  key EducationId,
  EmployeeId,
  Degree,
  FieldOfStudy,
  Institution,
  GraduationDate,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
