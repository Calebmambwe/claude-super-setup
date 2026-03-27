/**
 * Deepgram Nova-2 Streaming Speech-to-Text Client
 *
 * WebSocket client for real-time audio transcription.
 * Streams audio chunks and emits transcription events.
 */

import { EventEmitter } from "events";

export interface DeepgramConfig {
  apiKey: string;
  model?: string;
  language?: string;
  punctuate?: boolean;
  interimResults?: boolean;
  sampleRate?: number;
  channels?: number;
  encoding?: string;
}

export interface TranscriptionResult {
  text: string;
  isFinal: boolean;
  confidence: number;
  timestamp: number;
  words?: Array<{ word: string; start: number; end: number; confidence: number }>;
}

type DeepgramSTTEvent = {
  transcript: [result: TranscriptionResult];
  open: [];
  close: [code: number, reason: string];
  error: [error: Error];
};

export class DeepgramSTT extends EventEmitter<DeepgramSTTEvent> {
  private ws: WebSocket | null = null;
  private config: Required<DeepgramConfig>;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 3;
  private reconnectDelay = 1000;
  private keepAliveInterval: ReturnType<typeof setInterval> | null = null;

  constructor(config: DeepgramConfig) {
    super();
    this.config = {
      apiKey: config.apiKey,
      model: config.model ?? "nova-2",
      language: config.language ?? "en",
      punctuate: config.punctuate ?? true,
      interimResults: config.interimResults ?? true,
      sampleRate: config.sampleRate ?? 16000,
      channels: config.channels ?? 1,
      encoding: config.encoding ?? "linear16",
    };
  }

  async connect(): Promise<void> {
    const params = new URLSearchParams({
      model: this.config.model,
      language: this.config.language,
      punctuate: String(this.config.punctuate),
      interim_results: String(this.config.interimResults),
      sample_rate: String(this.config.sampleRate),
      channels: String(this.config.channels),
      encoding: this.config.encoding,
      endpointing: "300",
      utterance_end_ms: "1000",
    });

    const url = `wss://api.deepgram.com/v1/listen?${params}`;

    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(url, {
        // @ts-expect-error -- Node WebSocket accepts headers
        headers: { Authorization: `Token ${this.config.apiKey}` },
      });

      this.ws.onopen = () => {
        this.reconnectAttempts = 0;
        this.startKeepAlive();
        this.emit("open");
        resolve();
      };

      this.ws.onmessage = (event) => {
        this.handleMessage(event.data as string);
      };

      this.ws.onclose = (event) => {
        this.stopKeepAlive();
        this.emit("close", event.code, event.reason);
        if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.attemptReconnect();
        }
      };

      this.ws.onerror = () => {
        const error = new Error("Deepgram WebSocket error");
        this.emit("error", error);
        reject(error);
      };
    });
  }

  sendAudio(audioData: ArrayBuffer | Uint8Array): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(audioData);
    }
  }

  async close(): Promise<void> {
    this.stopKeepAlive();
    this.maxReconnectAttempts = 0; // prevent reconnect on intentional close
    if (this.ws?.readyState === WebSocket.OPEN) {
      // Send close message to get final transcript
      this.ws.send(JSON.stringify({ type: "CloseStream" }));
      await new Promise<void>((resolve) => {
        const timeout = setTimeout(() => {
          this.ws?.close();
          resolve();
        }, 3000);
        this.ws!.onclose = () => {
          clearTimeout(timeout);
          resolve();
        };
      });
    }
  }

  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  private handleMessage(data: string): void {
    try {
      const response = JSON.parse(data);

      if (response.type === "Results") {
        const alternative = response.channel?.alternatives?.[0];
        if (alternative) {
          const result: TranscriptionResult = {
            text: alternative.transcript ?? "",
            isFinal: response.is_final ?? false,
            confidence: alternative.confidence ?? 0,
            timestamp: Date.now(),
            words: alternative.words?.map(
              (w: { word: string; start: number; end: number; confidence: number }) => ({
                word: w.word,
                start: w.start,
                end: w.end,
                confidence: w.confidence,
              })
            ),
          };

          if (result.text.length > 0) {
            this.emit("transcript", result);
          }
        }
      }
    } catch {
      // ignore malformed messages
    }
  }

  private attemptReconnect(): void {
    this.reconnectAttempts++;
    const delay = this.reconnectDelay * this.reconnectAttempts;
    setTimeout(() => {
      this.connect().catch((err) => {
        this.emit("error", err instanceof Error ? err : new Error(String(err)));
      });
    }, delay);
  }

  private startKeepAlive(): void {
    this.keepAliveInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: "KeepAlive" }));
      }
    }, 10000);
  }

  private stopKeepAlive(): void {
    if (this.keepAliveInterval) {
      clearInterval(this.keepAliveInterval);
      this.keepAliveInterval = null;
    }
  }
}
