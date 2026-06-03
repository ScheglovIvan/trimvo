enum ReportReason {
  involvesMinor,
  sexualContent,
  harassment,
  hateDiscrimination,
  violence,
  selfHarm,
  realPerson,
  illegalActivity,
  copyright,
  spam,
  other,
}

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
        ReportReason.involvesMinor => 'Involves minor',
        ReportReason.sexualContent => 'Sexual or nude content',
        ReportReason.harassment => 'Harassment or threatening',
        ReportReason.hateDiscrimination => 'Hate or discrimination',
        ReportReason.violence => 'Violence or disturbing content',
        ReportReason.selfHarm => 'Self-harm or suicidal intent',
        ReportReason.realPerson => 'Real person without consent',
        ReportReason.illegalActivity => 'Illegal activity',
        ReportReason.copyright => 'Copyright violation',
        ReportReason.spam => 'Spam or abuse',
        ReportReason.other => 'Other',
      };

  String get apiValue => switch (this) {
        ReportReason.involvesMinor => 'involves_minor',
        ReportReason.sexualContent => 'sexual_content',
        ReportReason.harassment => 'harassment',
        ReportReason.hateDiscrimination => 'hate_discrimination',
        ReportReason.violence => 'violence',
        ReportReason.selfHarm => 'self_harm',
        ReportReason.realPerson => 'real_person',
        ReportReason.illegalActivity => 'illegal_activity',
        ReportReason.copyright => 'copyright',
        ReportReason.spam => 'spam',
        ReportReason.other => 'other',
      };
}
