@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Document - Interface'
define view entity ZI_HCM_Document
  as select from zhcm_document
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key document_id              as DocumentId,
      employee_id              as EmployeeId,
      doc_type                as DocType,
      drive_url               as DriveUrl,
      upload_date              as UploadDate,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
