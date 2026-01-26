import { Controller, Get, Post, Body, UseGuards, Request } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { TodosService } from './todos.service';

@Controller('todos')
@UseGuards(AuthGuard('jwt'))
export class TodosController {
    constructor(private readonly todosService: TodosService) { }

    @Post()
    create(@Request() req, @Body() body: any) {
        return this.todosService.create(req.user.id, req.user.teamId, body);
    }

    @Get('my')
    getMyTodos(@Request() req) {
        return this.todosService.findMyTodos(req.user.id);
    }

    @Get('team')
    getTeamTodos(@Request() req) {
        return this.todosService.findTeamTodos(req.user.teamId);
    }
}
