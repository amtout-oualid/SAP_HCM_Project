@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Onboarding Form - Interface'
define root view entity ZI_HCM_Onboarding
  as select from zhcm_onboardng
  association [1] to ZI_HCM_Application as _Application
    on $projection.ApplicationId = _Application.ApplicationId
{
  key form_id                 as FormId,
      application_id            as ApplicationId,
      employee_id              as EmployeeId,
      first_name               as FirstName,
      last_name               as LastName,
      date_of_birth             as DateOfBirth,
      place_of_birth            as PlaceOfBirth,
      nationality              as Nationality,
      marital_status            as MaritalStatus,
      gender                 as Gender,
      national_id              as NationalId,
      ssn                    as Ssn,
      address                 as Address,
      phone                  as Phone,
      personal_email            as PersonalEmail,
      bank_name               as BankName,
      bank_account             as BankAccount,
      iban                   as Iban,
      emergency_name            as EmergencyName,
      emergency_phone            as EmergencyPhone,
      emergency_relation          as EmergencyRelation,
      status                 as Status,
      submitted_at             as SubmittedAt,
      approved_by              as ApprovedBy,
      approved_at              as ApprovedAt,
      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Application
}
