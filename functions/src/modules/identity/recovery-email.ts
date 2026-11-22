export interface TransactionalEmail {
  to: string;
  subject: string;
  htmlContent: string;
  textContent: string;
}

export interface EmailService {
  send(message: TransactionalEmail): Promise<void>;
}

export class BrevoEmailService implements EmailService {
  constructor(private readonly apiKey: string, private readonly senderEmail: string) {}

  async send(message: TransactionalEmail): Promise<void> {
    const { to, ...content } = message;
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'api-key': this.apiKey, 'content-type': 'application/json' },
      body: JSON.stringify({
        ...content,
        sender: { name: 'GainPath', email: this.senderEmail },
        to: [{ email: to }],
      }),
      signal: AbortSignal.timeout(8000),
    });
    await response.body?.cancel();
    if (!response.ok) throw new Error('Transactional email rejected');
  }
}

export function passwordResetEmail(to: string, code: string, logoUrl = ''): TransactionalEmail {
  if (!/^\d{6}$/.test(code)) throw new Error('Invalid email code');
  const logo = logoUrl && /^https:\/\/[a-z0-9.-]+\/[a-z0-9_./%-]+$/i.test(logoUrl)
    ? `<img src="${logoUrl}" alt="" width="52" style="display:block;margin:0 auto 8px;border:0;">`
    : '';
  const lines = [
    'We received a request to reset your GainPath password. Enter the verification code below in your GainPath app.',
    'This code expires in 10 minutes.',
    'Never share this code with anyone.',
    "If you didn't request a password reset, you can safely ignore this email.",
    'Stay strong. Keep progressing.',
    'The GainPath Team',
  ];
  return {
    to,
    subject: 'Your GainPath password reset code',
    textContent: ['GainPath', 'Reset your password', lines[0], code, ...lines.slice(1)].join('\n\n'),
    htmlContent: `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;background:#f4effb;color:#231937;font-family:Arial,sans-serif;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f4effb"><tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#ffffff" style="max-width:520px;border-radius:16px;">
<tr><td align="center" style="padding:30px 24px;border-top:4px solid #f59442;border-radius:16px;">
${logo}<strong style="color:#6524c5;font-size:20px;">GainPath</strong>
<h1 style="font-size:26px;margin:24px 0 12px;">Reset your password</h1>
<p style="line-height:1.55;">${lines[0]}</p>
<p style="background:#f4effb;color:#6524c5;font-size:30px;font-weight:bold;letter-spacing:5px;padding:16px;">${code}</p>
<p style="line-height:1.55;">${lines[1]}<br>${lines[2]}</p>
<p style="color:#5f566d;line-height:1.55;">${lines[3]}</p>
<p style="line-height:1.55;">${lines[4]}<br><strong>${lines[5]}</strong></p>
</td></tr></table></td></tr></table></body></html>`,
  };
}
