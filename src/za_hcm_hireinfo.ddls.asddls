@EndUserText.label: 'Hire Information Popup'
define abstract entity ZA_HCM_HireInfo
{
  @EndUserText.label: 'Offered Salary (Annual)'
  @Semantics.amount.currencyCode: 'CurrencyCode'
  OfferedSalary : abap.curr(15,2);
  
  @EndUserText.label: 'Currency'
  CurrencyCode : abap.cuky;

  @EndUserText.label: 'Start Date'
  StartDate : abap.dats;

  @EndUserText.label: 'HR Notes'
  Notes : abap.string;
}
