"use client";
import { v4 as uuidv4 } from "uuid";
import { useState, useEffect, useRef, FormEvent } from "react";
import { useAuth } from "@clerk/nextjs";
import DatePicker from "react-datepicker";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkBreaks from "remark-breaks";
import { fetchEventSource } from "@microsoft/fetch-event-source";
import { Protect, PricingTable, UserButton } from "@clerk/nextjs";

function ConsultationForm() {
  const { getToken, userId } = useAuth();
  const consultationIdRef = useRef<string | null>(null);

  useEffect(() => {
    consultationIdRef.current = uuidv4();
  }, []);

  // Form state
  const [patientName, setPatientName] = useState("");
  const [patientEmail, setPatientEmail] = useState("");
  const [visitDate, setVisitDate] = useState<Date | null>(new Date());
  const [notes, setNotes] = useState("");

  // Streaming state
  const [output, setOutput] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setOutput("");
    setErrorMessage("");
    setLoading(true);
    const jwt = await getToken({
      template: "test_jwt_template",
      skipCache: true,
    });
    if (!jwt) {
      setOutput("Authentication required");
      setLoading(false);
      return;
    }

    const controller = new AbortController();
    let buffer = "";

    const rawBase = process.env.NEXT_PUBLIC_BACKEND_URL || "";
    const base = rawBase.replace(/\/$/, "");
    const consultationUrl = base
      ? `${base}/api/consultation`
      : `/api/consultation`;

    await fetchEventSource(consultationUrl, {
      signal: controller.signal,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${jwt}`,
        "Session-Id": consultationIdRef.current || "",
      },
      body: JSON.stringify({
        patient_name: patientName,
        patient_email: patientEmail,
        date_of_visit: visitDate?.toISOString().slice(0, 10),
        notes,
      }),
      async onopen(response) {
        if (response.status >= 400) {
          throw new Error(`Failed to connect: ${response.statusText}`);
        }
      },
      async onmessage(ev) {
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
          controller.abort();
          return;
        }
        buffer += ev.data;
        setOutput(buffer);
      },
      onclose() {
        setLoading(false);
      },
      onerror(err) {
        console.error("SSE error:", err);
        controller.abort();
        setLoading(false);
      },
    });
  }

  //   await fetchEventSource(consultationUrl, {
  //     signal: controller.signal,
  //     openWhenHidden: true,
  //     method: "POST",
  //     headers: {
  //       "Content-Type": "application/json",
  //       Authorization: `Bearer ${jwt}`,
  //       "Session-Id": consultationIdRef.current || "",
  //     },
  //     body: JSON.stringify({
  //       patient_name: patientName,
  //       patient_email: patientEmail,
  //       date_of_visit: visitDate?.toISOString().slice(0, 10),
  //       notes,
  //     }),
  //     fetch: async (input, init) => {
  //       let response = await fetch(input, {
  //         ...init,
  //         headers: {
  //           ...(init?.headers || {}),
  //           Authorization: `Bearer ${jwt}`,
  //         },
  //       });
  //       if (response.status == 401 || response.status == 403) {
  //         // Handle unauthorized or forbidden response
  //         console.error("Unauthorized or forbidden request");
  //         const jwt = await getToken({
  //           template: "test_jwt_template",
  //           skipCache: true,
  //         });

  //         //Retry with a fresh token
  //         response = await fetch(input, {
  //           ...init,
  //           headers: {
  //             ...(init?.headers || {}),
  //             Authorization: `Bearer ${jwt}`,
  //           },
  //         });
  //       }

  //       return response;
  //     },
  //     onopen: async (response) => {
  //       if (response.status >= 400) {
  //         throw new Error(`Failed to connect: ${response.statusText}`);
  //       }
  //     },
  //     onmessage: async (ev) => {
  //       if (ev.event === "error") {
  //         let message =
  //           "We couldn’t validate your consultation notes. Please try again.";
  //         try {
  //           const payload: unknown = JSON.parse(ev.data);
  //           if (
  //             typeof payload === "object" &&
  //             payload !== null &&
  //             "message" in payload &&
  //             typeof payload.message === "string"
  //           ) {
  //             message = payload.message;
  //           }
  //         } catch {
  //           message =
  //             "We couldn’t validate your consultation notes. Please try again.";
  //         }
  //         setErrorMessage(message);
  //         setLoading(false);
  //         controller.abort();
  //         return;
  //       }
  //       buffer += ev.data;
  //       setOutput(buffer);
  //     },
  //     onclose: () => {
  //       debugger;
  //       setLoading(false);
  //     },
  //     onerror: (err) => {
  //       debugger;
  //       console.error("SSE error:", err);
  //       controller.abort();
  //       setLoading(false);
  //     },
  //   });
  // }

  return (
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
            {notes.trim() ? notes.trim().split(/\s+/).length : 0} / 500 words
          </p>
        </div>

        {errorMessage && (
          <p
            role="alert"
            className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300"
          >
            {errorMessage}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-6 rounded-lg transition-colors duration-200"
        >
          {loading ? "Generating Prescription..." : "Generate Prescription"}
        </button>
      </form>

      {output && (
        <section className="mt-8 bg-gray-50 dark:bg-gray-800 rounded-xl shadow-lg p-8">
          <div className="markdown-content prose prose-blue dark:prose-invert max-w-none">
            <ReactMarkdown remarkPlugins={[remarkGfm, remarkBreaks]}>
              {output}
            </ReactMarkdown>
          </div>
        </section>
      )}
    </div>
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
