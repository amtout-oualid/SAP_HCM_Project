@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Document
  as projection on ZI_HCM_Document
{
  key DocumentId,
  EmployeeId,
  DocType,
  DriveUrl,
  UploadDate,
  LocalLastChangedAt,
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
