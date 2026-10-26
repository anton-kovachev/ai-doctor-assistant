import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkBreaks from "remark-breaks";

type ConsultationResultModalProps = {
  open: boolean;
  loading: boolean;
  activity: string[];
  interruptions: string[];
  output: string;
  errorMessage: string;
  onClose: () => void;
  onCancel: () => void;
  onApprove: () => void;
  onReject: () => void;
};

export default function ConsultationResultModal({
  open,
  loading,
  activity,
  interruptions,
  output,
  errorMessage,
  onClose,
  onCancel,
  onApprove,
  onReject,
}: ConsultationResultModalProps) {
  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <section
        aria-labelledby="consultation-result-title"
        aria-modal="true"
        className="max-h-[90vh] w-full max-w-3xl overflow-y-auto rounded-xl bg-white p-6 shadow-2xl dark:bg-gray-800 sm:p-8"
        role="dialog"
      >
        <div className="mb-6 flex items-start justify-between gap-4">
          <h2
            className="text-2xl font-bold text-gray-900 dark:text-gray-100"
            id="consultation-result-title"
          >
            {loading ? "Generating consultation" : "Consultation result"}
          </h2>
          {loading ? (
            <button
              aria-label="Cancel request and close consultation"
              className="rounded-lg bg-red-600 px-3 py-1 font-semibold text-white hover:bg-red-700"
              onClick={onCancel}
              type="button"
            >
              Cancel
            </button>
          ) : interruptions.length === 0 ? (
            <button
              aria-label="Close consultation result"
              className="rounded px-3 py-1 font-bold text-white hover:brightness-90"
              onClick={onClose}
              style={{ backgroundColor: "lab(44.0605 29.0279 -86.0352)" }}
              type="button"
            >
              Close
            </button>
          ) : null}
        </div>

        {errorMessage && (
          <p
            className="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300"
            role="alert"
          >
            {errorMessage}
          </p>
        )}

        {loading ? (
          <div aria-live="polite" className="space-y-5">
            <div className="flex items-center gap-3 text-gray-700 dark:text-gray-200">
              <span
                aria-label="Loading"
                className="h-6 w-6 animate-spin rounded-full border-2 border-blue-600 border-t-transparent"
                role="status"
              />
              <span>Preparing the consultation summary…</span>
            </div>
            {activity.length > 0 && (
              <section aria-label="Recent activity">
                <h3 className="mb-2 font-semibold text-gray-800 dark:text-gray-100">
                  Recent activity
                </h3>
                <ul className="space-y-2 text-sm text-gray-600 dark:text-gray-300">
                  {activity.slice(-5).map((message, index) => (
                    <li
                      className="rounded-lg bg-gray-100 px-3 py-2 dark:bg-gray-700"
                      key={`${index}-${message}`}
                    >
                      {message}
                    </li>
                  ))}
                </ul>
              </section>
            )}
          </div>
        ) : (
          <div className="space-y-6">
            {output ? (
              <div className="markdown-content prose prose-blue max-w-none dark:prose-invert">
                <ReactMarkdown remarkPlugins={[remarkGfm, remarkBreaks]}>
                  {output}
                </ReactMarkdown>
              </div>
            ) : (
              !errorMessage && (
                <p className="text-gray-600 dark:text-gray-300">
                  No consultation output was received.
                </p>
              )
            )}

            {interruptions.length > 0 && (
              <section
                aria-label="Pending interruptions"
                className="border-t border-gray-200 pt-5 dark:border-gray-700"
              >
                <h3 className="mb-2 text-lg font-semibold text-gray-900 dark:text-gray-100">
                  Approval required (applies to all listed requests)
                </h3>

                <ul className="mb-4 list-inside list-disc space-y-1 text-gray-700 dark:text-gray-200">
                  {interruptions.map((message, index) => (
                    <li key={`${index}-${message}`}>
                      {message
                        .split("_")
                        .map(
                          (word) =>
                            word.charAt(0).toUpperCase() +
                            word.slice(1).toLowerCase(),
                        )
                        .join(" ")}
                    </li>
                  ))}
                </ul>
                <div className="flex gap-3">
                  <button
                    className="rounded-lg bg-green-600 px-4 py-2 font-semibold text-white hover:bg-green-700"
                    onClick={onApprove}
                    type="button"
                    disabled={loading}
                  >
                    Approve
                  </button>
                  <button
                    className="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700"
                    onClick={onReject}
                    type="button"
                    disabled={loading}
                  >
                    Reject
                  </button>
                </div>
              </section>
            )}
          </div>
        )}
        {!loading && interruptions.length === 0 && (
          <div className="mt-6 flex justify-center">
            <button
              aria-label="Close consultation result"
              className="rounded px-3 py-1 font-bold text-white hover:brightness-90"
              onClick={onClose}
              style={{ backgroundColor: "lab(44.0605 29.0279 -86.0352)" }}
              type="button"
            >
              Close
            </button>
          </div>
        )}
      </section>
    </div>
  );
}
