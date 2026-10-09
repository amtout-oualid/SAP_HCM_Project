@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Employee Status'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_HCM_VH_EmpStatus as select from zhcm_empstat {
      @ObjectModel.text.element: ['Description']
  key status as Status,
      description as Description
}
