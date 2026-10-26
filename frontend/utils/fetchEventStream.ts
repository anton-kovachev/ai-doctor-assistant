import {
  fetchEventSource,
  EventSourceMessage,
} from "@microsoft/fetch-event-source";
import { Dispatch, SetStateAction } from "react";
import { ConfirmationRequest } from "../models/confirmation";
import { ConsulationRequest } from "../models/consulation";

type StreamRequest = ConsulationRequest | ConfirmationRequest;
type GetToken = () => Promise<string | null>;

class HttpResponseError extends Error {
  constructor(
    readonly status: number,
    statusText: string,
  ) {
    super(`Failed to connect: ${statusText}`);
  }
}

const MAX_AUTHORIZATION_RETRIES = 10;
const AUTHORIZATION_RETRY_DELAY_MS = 1000;

type FetchEventStreamOptions = {
  abortController?: AbortController;
  sessionId?: string | null;
  onMessage?: (event: EventSourceMessage, abort: () => void) => boolean;
  onOpen?: () => void;
  onClose?: () => void;
  onTransportError?: (error: unknown) => number | undefined;
};

export async function fetchEventStream(
  url: string,
  body: StreamRequest,
  setOutput: Dispatch<SetStateAction<string>>,
  getToken?: GetToken,
  options: FetchEventStreamOptions = {},
): Promise<void> {
  const controller = options.abortController ?? new AbortController();
  if (controller.signal.aborted) {
    return;
  }

  let token: string | null = getToken ? await getToken() : null;
  if (controller.signal.aborted) {
    return;
  }
  if (getToken && !token) {
    throw new Error("Authentication required");
  }

  let authenticationError: unknown;
  let authorizationRetries = 0;
  let output = "";

  await fetchEventSource(url, {
    signal: controller.signal,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.sessionId ? { "X-Session-ID": options.sessionId } : {}),
    },
    body: JSON.stringify(body),
    fetch: async (input, init) => {
      let response = await fetch(input, init);

      if (getToken && (response.status === 401 || response.status === 403)) {
        try {
          token = await getToken();
          if (!token) {
            throw new Error("Authentication required");
          }
        } catch (error) {
          authenticationError = error;
          throw error;
        }

        const headers = new Headers(init?.headers);
        headers.set("Authorization", `Bearer ${token}`);
        response = await fetch(input, { ...init, headers });
      } else if (response.status >= 400) {
        controller.abort();
      }

      return response;
    },
    async onopen(response) {
      if (response.status >= 400) {
        throw new HttpResponseError(response.status, response.statusText);
      }
      options.onOpen?.();
    },
    onmessage(event) {
      if (options.onMessage?.(event, () => controller.abort())) {
        return;
      }

      output += event.data;
      if (output) {
        setOutput(output);
      }
    },
    onclose() {
      options.onClose?.();
    },
    onerror(error) {
      if (authenticationError) {
        throw authenticationError;
      }

      if (
        error instanceof HttpResponseError &&
        (error.status === 401 || error.status === 403)
      ) {
        options.onTransportError?.(error);
        if (authorizationRetries >= MAX_AUTHORIZATION_RETRIES) {
          throw error;
        }
        authorizationRetries += 1;
        return AUTHORIZATION_RETRY_DELAY_MS;
      }

      return options.onTransportError?.(error) || controller.abort();
    },
  });
}
