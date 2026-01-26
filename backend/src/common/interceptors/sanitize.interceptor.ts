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
    intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
        return next.handle().pipe(
            map(data => this.sanitize(data)),
        );
    }

    private sanitize(data: any): any {
        if (!data || typeof data !== 'object') return data;
        if (Array.isArray(data)) return data.map(v => this.sanitize(v));

        const sanitized = { ...data };
        delete sanitized.password;
        // Add other sensitive fields to remove here

        // Recursively sanitize any remaining objects
        Object.keys(sanitized).forEach(key => {
            if (typeof sanitized[key] === 'object') {
                sanitized[key] = this.sanitize(sanitized[key]);
            }
        });

        return sanitized;
    }
}
