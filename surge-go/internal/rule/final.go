package rule

// FinalRule matches everything
type FinalRule struct {
	BaseRule
}

func NewFinalRule(adapter string) *FinalRule {
	return &FinalRule{
		BaseRule: BaseRule{
			RuleType:    "FINAL",
			RulePayload: "",
			AdapterName: adapter,
		},
	}
}

func (r *FinalRule) Match(metadata *RequestMetadata) bool {
	return true
}
