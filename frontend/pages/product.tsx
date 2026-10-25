"use client";

import { useState, useEffect, useRef, FormEvent } from "react";
import { useAuth } from "@clerk/nextjs";
import DatePicker from "react-datepicker";
import ConsultationResultModal from "../components/ConsultationResultModal";
import {
  Protect,
  PricingTable,
  SignInButton,
  SignedIn,
  SignedOut,
  UserButton,
} from "@clerk/nextjs";
import { ConsulationRequest } from "../models/consulation";
import { ConfirmationRequest } from "../models/confirmation";
import { fetchEventStream } from "../utils/fetchEventStream";
import { EmailPrescriptionConfirmationRequest } from "../models/confirmation";

const BASE_API_URL = (process.env.NEXT_PUBLIC_BACKEND_URL || "").replace(
  /\/$/,
  "",
);

function isEmailPrescriptionConfirmationRequest(
  value: unknown,
): value is EmailPrescriptionConfirmationRequest {
  return (
    typeof value === "object" &&
    value !== null &&
    "to_email" in value &&
    typeof value.to_email === "string" &&
    "subject" in value &&
    typeof value.subject === "string" &&
    "text_body" in value &&
    typeof value.text_body === "string" &&
    "html_body" in value &&
    typeof value.html_body === "string"
  );
}

function parseHtml(html: string): string {
  return (
    new DOMParser().parseFromString(html, "text/html").body.textContent ?? ""
  );
}

function ConsultationForm() {
  const { getToken } = useAuth();

  // Form state
  const [patientName, setPatientName] = useState("");
  const [patientEmail, setPatientEmail] = useState("");
  const [visitDate, setVisitDate] = useState<Date | null>(new Date());
  const [notes, setNotes] = useState("");

  // Streaming state
  const [output, setOutput] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [activity, setActivity] = useState<string[]>([]);
  const [interruptions, setInterruptions] = useState<string[]>([]);
  const sessionId = useRef<string | null>(null);

  useEffect(() => {
    sessionId.current = crypto.randomUUID();
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setOutput("");
    setErrorMessage("");
    setActivity([]);
    setInterruptions([]);
    setLoading(true);
    setModalOpen(true);

    await fetchConsultation();
  }

  async function fetchConsultation() {
    const consultationUrl = BASE_API_URL
      ? `${BASE_API_URL}/api/consultation`
      : `/api/consultation`;
    const body: ConsulationRequest = {
      patient_name: patientName,
      patient_email: patientEmail,
      date_of_visit: visitDate?.toISOString().slice(0, 10) ?? "",
      notes,
    };

    try {
      await fetchEventStream(
        consultationUrl,
        body,
        setOutput,
        () =>
          getToken({
            template: "test_jwt_template",
            skipCache: true,
          }),
        {
          sessionId: sessionId.current,
          onOpen: () => setErrorMessage(""),
          onClose: () => setLoading(false),
          onMessage(ev, abort) {
            console.log(
              `Event received: event:${ev.event} data: ${ev.data} id: ${ev.id}`,
            );
            if (ev.event === "progress") {
              setActivity((current) => [...current, ev.data].slice(-5));
              return true;
            }
            if (ev.event === "interruption") {
              let payload: unknown;
              try {
                payload = JSON.parse(ev.data);
              } catch (error) {
                if (!(error instanceof SyntaxError)) {
                  throw error;
                }
                console.error("Invalid interruption event payload:", error);
                setErrorMessage(
                  "Could not read the approval request from the server.",
                );
                return true;
              }
              if (
                typeof payload !== "object" ||
                payload === null ||
                !("pending_action" in payload) ||
                typeof payload.pending_action !== "string"
              ) {
                setErrorMessage("The server sent an invalid approval request.");
                return true;
              }
              const actionName = payload.pending_action;

              if (
                "arguments" in payload &&
                isEmailPrescriptionConfirmationRequest(payload.arguments)
              ) {
                setOutput(
                  `##${payload.arguments.subject}\n${payload.arguments.text_body || parseHtml(payload.arguments.html_body)}`,
                );
              }

              setInterruptions((current) => [...current, actionName]);
              return true;
            }
            if (ev.event === "error") {
              let message =
                "We couldn’t validate your consultation notes. Please try again.";
              try {
                const payload: unknown = JSON.parse(ev.data);
                if (
                  typeof payload === "object" &&
                  payload !== null &&
                  "message" in payload &&
                  typeof payload.message === "string"
                ) {
                  message = payload.message;
                }
              } catch {
                message =
                  "We couldn’t validate your consultation notes. Please try again.";
              }
              setErrorMessage(message);
              setLoading(false);
              abort();
              return true;
            }
            return false;
          },
          onTransportError(err) {
            setErrorMessage(
              "An error occurred while streaming the consultation. Retrying...",
            );
            console.error("SSE error:", err);
            return 1000;
          },
        },
      );
    } catch (error) {
      console.error("Consultation stream failed:", error);
      setErrorMessage(
        error instanceof Error ? error.message : "Authentication required",
      );
      setLoading(false);
    }
  }

  async function handleApproveInterruptions() {
    console.info(
      "Approve interruptions (frontend placeholder):",
      interruptions,
    );
    await handleConfirmInterruptions(true);
  }

  async function handleRejectInterruptions() {
    console.info("Reject interruptions (frontend placeholder):", interruptions);
    setLoading(true);
    try {
      await handleConfirmInterruptions(false);
    } finally {
      setLoading(false);
    }
  }

  async function handleConfirmInterruptions(approved: boolean) {
    console.info(
      "Confirm interruptions (frontend placeholder):",
      interruptions,
    );
    setOutput("");
    await submitConfirmation({
      actions: interruptions.map((action) => ({
        action_name: action,
        is_approved: approved,
      })),
    });
    setInterruptions([]);
  }

  async function submitConfirmation(request: ConfirmationRequest) {
    const confirmationUrl = BASE_API_URL
      ? `${BASE_API_URL}/api/confirmation`
      : `/api/confirmation`;
    try {
      await fetchEventStream(
        confirmationUrl,
        request,
        setOutput,
        () =>
          getToken({
            template: "test_jwt_template",
            skipCache: true,
          }),
        { sessionId: sessionId.current },
      );
    } catch (error) {
      console.error("Confirmation stream failed:", error);
      setErrorMessage(
        error instanceof Error ? error.message : "Authentication required",
      );
      setLoading(false);
    }
  }

  return (
    <>
      <SignedIn>
        <div className="container mx-auto px-4 py-12 max-w-3xl">
          <h1 className="text-4xl font-bold text-gray-900 dark:text-gray-100 mb-8">
            AI Dr.
          </h1>

          <form
            onSubmit={handleSubmit}
            className="space-y-6 bg-white dark:bg-gray-800 rounded-xl shadow-lg p-8"
          >
            <div className="space-y-2">
              <label
                htmlFor="patient"
                className="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                Patient Name
              </label>
              <input
                id="patient"
                type="text"
                required
                value={patientName}
                onChange={(e) => setPatientName(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-700 dark:text-white"
                placeholder="Enter patient's full name"
              />
            </div>

            <div className="space-y-2">
              <label
                htmlFor="email"
                className="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                Patient Email
              </label>
              <input
                id="email"
                type="email"
                required
                value={patientEmail}
                onChange={(e) => setPatientEmail(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-700 dark:text-white"
                placeholder="Enter patient's email address"
              />
            </div>

            <div className="space-y-2">
              <label
                htmlFor="date"
                className="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                Date of Visit
              </label>
              <DatePicker
                id="date"
                selected={visitDate}
                onChange={(d: Date | null) => setVisitDate(d)}
                dateFormat="yyyy-MM-dd"
                placeholderText="Select date"
                required
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-700 dark:text-white"
              />
            </div>

            <div className="space-y-2">
              <label
                htmlFor="notes"
                className="block text-sm font-medium text-gray-700 dark:text-gray-300"
              >
                Complain
              </label>
              <textarea
                id="notes"
                required
                rows={8}
                value={notes}
                onChange={(e) => {
                  setNotes(e.target.value);
                  setErrorMessage("");
                }}
                aria-describedby="notes-word-count"
                className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-700 dark:text-white"
                placeholder="Enter detailed consultation notes..."
              />
              <p
                id="notes-word-count"
                className="text-sm text-gray-500 dark:text-gray-400"
              >
                {notes.trim() ? notes.trim().split(/\s+/).length : 0} / 500
                words
              </p>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-6 rounded-lg transition-colors duration-200"
            >
              {loading ? "Generating Prescription..." : "Generate Prescription"}
            </button>
          </form>
        </div>
        <ConsultationResultModal
          activity={activity}
          errorMessage={errorMessage}
          interruptions={interruptions}
          loading={loading}
          onApprove={handleApproveInterruptions}
          onClose={() => setModalOpen(false)}
          onReject={handleRejectInterruptions}
          open={modalOpen}
          output={output}
        />
      </SignedIn>
      <SignedOut>
        <SignInButton />
      </SignedOut>
    </>
  );
}

export default function Product() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      {/* User Menu in Top Right */}
      <div className="absolute top-4 right-4">
        <UserButton showName={true} />
      </div>

      {/* Subscription Protection */}
      <Protect
        plan="premium_subscription"
        fallback={
          <div className="container mx-auto px-4 py-12">
            <header className="text-center mb-12">
              <h1 className="text-5xl font-bold bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent mb-4">
                Healthcare Professional Plan
              </h1>
              <p className="text-gray-600 dark:text-gray-400 text-lg mb-8">
                Streamline your patient consultations with AI-powered summaries
              </p>
            </header>
            <div className="max-w-4xl mx-auto">
              <PricingTable />
            </div>
          </div>
        }
      >
        <ConsultationForm />
      </Protect>
    </main>
  );
}
