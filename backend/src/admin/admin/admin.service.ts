import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma/prisma.service';
import { stringify } from 'csv-stringify/sync';

@Injectable()
export class AdminService {
    constructor(private prisma: PrismaService) { }

    async exportTeamTodosCsv(teamId: string) {
        const todos = await this.prisma.todo.findMany({
            where: { teamId: teamId },
            include: { author: true },
            orderBy: { createdAt: 'desc' },
        });

        const data = todos.map(todo => ({
            Date: todo.createdAt.toISOString().split('T')[0],
            'User Name': todo.author.displayName,
            Content: todo.content,
            Priority: todo.priority,
            Status: todo.isCompleted ? 'Completed' : 'Pending',
        }));

        return stringify(data, { header: true });
    }
}
