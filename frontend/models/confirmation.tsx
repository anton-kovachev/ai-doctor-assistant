export type ConfirmationActionRequest = {
  action_name: string;
  is_approved: boolean;
};

export type ConfirmationRequest = {
  actions: Array<ConfirmationActionRequest>;
};

export type TreatmentPlanEmailConfirmationRequest = {
  to_email: string;
  subject: string;
  text_body: string;
  html_body: string;
};
