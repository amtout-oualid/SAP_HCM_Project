@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Org Assignment - Interface'
define view entity ZI_HCM_OrgAssign
  as select from zhcm_orgassign
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
  association [0..1] to ZI_HCM_OrgUnit as _OrgUnit
    on $projection.OrgUnitId = _OrgUnit.OrgUnitId
  association [0..1] to ZI_HCM_Position as _Position
    on $projection.PositionId = _Position.PositionId
{
  key org_assignment_id         as AssignId,
      employee_id              as EmployeeId,
      position_id              as PositionId,
      org_unit_id              as OrgUnitId,
      job_title               as JobTitle,
      department              as Department,
      manager_id               as ManagerId,
      valid_from               as ValidFrom,
      valid_to                as ValidTo,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee,
      _OrgUnit,
      _Position
}
