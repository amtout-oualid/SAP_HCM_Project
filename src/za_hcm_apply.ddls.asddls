@EndUserText.label: 'Apply to Job Parameter'
define abstract entity ZA_HCM_Apply
{
  OfferId          : sysuuid_x16;
  ResumeUrl        : abap.string(0);
  CoverLetter      : abap.string(0);
  NoticePeriod     : abap.char(20);
  @Semantics.amount.currencyCode: 'CurrencyCode'
  SalaryExpectation: abap.curr(15,2);
  CurrencyCode     : abap.cuky(5);
}
