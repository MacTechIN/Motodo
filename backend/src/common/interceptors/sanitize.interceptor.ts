import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

@Injectable()
export class SanitizeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(map((data: unknown) => this.sanitize(data)));
  }

  private sanitize(data: unknown): unknown {
    if (!data || typeof data !== 'object') return data;
    if (Array.isArray(data)) return data.map((v: unknown) => this.sanitize(v));

    const sanitized = { ...(data as Record<string, unknown>) };
    delete sanitized.password;
    // Add other sensitive fields to remove here

    // Recursively sanitize any remaining objects
    Object.keys(sanitized).forEach((key) => {
      const val = sanitized[key];
      if (val !== null && typeof val === 'object') {
        sanitized[key] = this.sanitize(val);
      }
    });

    return sanitized;
  }
}
