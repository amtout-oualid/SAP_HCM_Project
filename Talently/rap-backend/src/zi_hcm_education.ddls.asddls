@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Education - Interface'
define view entity ZI_HCM_Education
  as select from zhcm_education
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key education_id             as EducationId,
      employee_id              as EmployeeId,
      degree                 as Degree,
      field_of_study            as FieldOfStudy,
      institution              as Institution,
      graduation_date            as GraduationDate,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
