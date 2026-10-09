@EndUserText.label: 'AI Evaluation Result Parameter'
define abstract entity ZA_HCM_AIResult
{
  @EndUserText.label: 'AI Score'
  Score          : abap.dec(5,2);

  @EndUserText.label: 'Recommendation'
  Recommendation : abap.char(20);

  @EndUserText.label: 'Summary'
  Summary        : abap.string(1000);
}
