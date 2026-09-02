@EndUserText.label: 'Hire Information Popup'
define abstract entity ZA_HCM_HireInfo
{
  @EndUserText.label: 'Offered Salary (Annual)'
  OfferedSalary : abap.dec(15,2);
  
  @EndUserText.label: 'Start Date'
  StartDate : abap.dats;

  @EndUserText.label: 'HR Notes'
  Notes : abap.string;
}
