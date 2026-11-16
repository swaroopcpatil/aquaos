"use client";

import { useState } from "react";
import { explain, type Audience, type CalculationResponse, type ExplainResponse } from "@/lib/api";
import { QUESTION_MAX } from "@/lib/validation";
import { Card, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";

function List({ title, items }: { title: string; items: string[] }) {
  if (items.length === 0) return null;
  return (
    <div>
      <h3 className="mb-1 text-sm font-semibold text-white">{title}</h3>
      <ul className="list-disc space-y-1 pl-5 text-sm text-slate-300">
        {items.map((x, i) => <li key={i}>{x}</li>)}
      </ul>
    </div>
  );
}

export function ExplainPanel({ calculation }: { calculation: CalculationResponse }) {
  const [audience, setAudience] = useState<Audience>("farmer");
  const [question, setQuestion] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<ExplainResponse | null>(null);

  const tooLong = question.length > QUESTION_MAX;

  async function run(e: React.FormEvent) {
    e.preventDefault();
    if (tooLong) return;
    setLoading(true);
    setError(null);
    try {
      const q = question.trim();
      setData(await explain({ calculation, audience, ...(q ? { question: q } : {}) }));
    } catch (err) {
      setData(null);
      setError(err instanceof Error ? err.message : "The explanation could not be generated.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card>
      <CardTitle>Explain these results</CardTitle>
      <form onSubmit={run} className="space-y-4" noValidate>
        <div className="max-w-xs">
          <Label htmlFor="audience">Audience</Label>
          <Select id="audience" value={audience} onChange={(e) => setAudience(e.target.value as Audience)}>
            <option value="farmer">Farmer</option>
            <option value="dealer">Dealer</option>
            <option value="technician">Technician</option>
          </Select>
        </div>
        <div>
          <Label htmlFor="question">Question (optional)</Label>
          <Textarea
            id="question"
            rows={3}
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            aria-invalid={tooLong}
            aria-describedby="question-hint"
          />
          <p id="question-hint" className={`mt-1 text-xs ${tooLong ? "text-red-300" : "text-slate-400"}`}>
            {question.length}/{QUESTION_MAX} characters{tooLong ? " - too long" : ""}
          </p>
        </div>
        <Button type="submit" disabled={loading || tooLong}>
          {loading ? "Generating explanation..." : "Explain"}
        </Button>
      </form>

      <div className="mt-4" aria-live="polite">
        {error && <Alert variant="error">{error}</Alert>}
        {data && (
          <div className="space-y-4 border-t border-line pt-4">
            <p className="text-slate-100">{data.summary}</p>
            <List title="Key points" items={data.key_points} />
            <List title="Assumptions" items={data.assumptions} />
            <List title="Follow-up questions" items={data.follow_up_questions} />
            <p className="text-xs text-slate-400">{data.disclaimer}</p>
            <p className="text-xs text-slate-500">Provider: {data.provider}</p>
          </div>
        )}
      </div>
    </Card>
  );
}
