import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { TodosService } from './todos.service';

@Controller('todos')
@UseGuards(AuthGuard('jwt'))
export class TodosController {
  constructor(private readonly todosService: TodosService) { }

  @Post()
  async create(
    @Request() req: { user: { id: string; teamId: string } },
    @Body() body: { content: string; priority: number; isSecret: boolean },
  ) {
    return await this.todosService.create(req.user.id, req.user.teamId, body);
  }

  @Get('my')
  async getMyTodos(@Request() req: { user: { id: string } }) {
    return await this.todosService.findMyTodos(req.user.id);
  }

  @Get('team')
  async getTeamTodos(@Request() req: { user: { teamId: string } }) {
    return await this.todosService.findTeamTodos(req.user.teamId);
  }
}
