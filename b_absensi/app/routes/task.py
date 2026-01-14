from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel
from datetime import datetime

from ..database import get_db
from ..models.user import User
from ..models.absensi import Task, TaskStatus
from ..middleware.auth_middleware import get_current_user

router = APIRouter()


class TaskCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    assigned_to_id: str
    due_date: Optional[str] = None
    priority: str = "normal"  # low, normal, high, urgent
    notes: Optional[str] = None


class TaskUpdateRequest(BaseModel):
    status: str
    completion_notes: Optional[str] = None


@router.post("/submit")
async def submit_task(
    request: TaskCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Submit a new task to be assigned to someone"""
    try:
        # Verify assigned_to user exists
        assigned_to = db.query(User).filter(User.id == request.assigned_to_id).first()
        if not assigned_to:
            raise HTTPException(status_code=404, detail="User not found")
        
        from ..models.absensi import get_jakarta_time
        
        task = Task(
            title=request.title,
            description=request.description,
            assigned_by_id=current_user.id,
            assigned_to_id=request.assigned_to_id,
            due_date=datetime.fromisoformat(request.due_date) if request.due_date else None,
            priority=request.priority,
            notes=request.notes,
            status=TaskStatus.PENDING,
        )
        
        db.add(task)
        db.commit()
        db.refresh(task)
        
        return {
            "message": "Task submitted successfully",
            "task_id": task.id,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error submitting task: {str(e)}")


@router.get("/assigned-to-me")
async def get_tasks_assigned_to_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all tasks assigned to current user"""
    try:
        tasks = db.query(Task).filter(
            Task.assigned_to_id == current_user.id
        ).order_by(Task.created_at.desc()).all()
        
        result = []
        for task in tasks:
            assigned_by = db.query(User).filter(User.id == task.assigned_by_id).first()
            
            result.append({
                "id": task.id,
                "title": task.title,
                "description": task.description,
                "assigned_by_name": assigned_by.name if assigned_by else "Unknown",
                "assigned_by_nip": assigned_by.nip if assigned_by else "Unknown",
                "due_date": task.due_date.isoformat() if task.due_date else None,
                "start_date": task.start_date.isoformat() if task.start_date else None,
                "end_date": task.end_date.isoformat() if task.end_date else None,
                "status": task.status,
                "priority": task.priority,
                "notes": task.notes,
                "completion_notes": task.completion_notes,
                "created_at": task.created_at.isoformat(),
            })
        
        return {"tasks": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting tasks: {str(e)}")


@router.get("/assigned-by-me")
async def get_tasks_assigned_by_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all tasks assigned by current user"""
    try:
        tasks = db.query(Task).filter(
            Task.assigned_by_id == current_user.id
        ).order_by(Task.created_at.desc()).all()
        
        result = []
        for task in tasks:
            assigned_to = db.query(User).filter(User.id == task.assigned_to_id).first()
            
            result.append({
                "id": task.id,
                "title": task.title,
                "description": task.description,
                "assigned_to_name": assigned_to.name if assigned_to else "Unknown",
                "assigned_to_nip": assigned_to.nip if assigned_to else "Unknown",
                "due_date": task.due_date.isoformat() if task.due_date else None,
                "start_date": task.start_date.isoformat() if task.start_date else None,
                "end_date": task.end_date.isoformat() if task.end_date else None,
                "status": task.status,
                "priority": task.priority,
                "notes": task.notes,
                "completion_notes": task.completion_notes,
                "created_at": task.created_at.isoformat(),
            })
        
        return {"tasks": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting tasks: {str(e)}")


@router.post("/{task_id}/update-status")
async def update_task_status(
    task_id: str,
    request: TaskUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update task status - can only be done by assigned user"""
    try:
        task = db.query(Task).filter(Task.id == task_id).first()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        if task.assigned_to_id != current_user.id:
            raise HTTPException(status_code=403, detail="You can only update tasks assigned to you")
        
        from ..models.absensi import get_jakarta_time
        
        task.status = request.status
        task.completion_notes = request.completion_notes
        
        if request.status == TaskStatus.COMPLETED:
            task.completed_at = get_jakarta_time()
        
        db.commit()
        
        return {"message": "Task status updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error updating task: {str(e)}")


@router.get("/{task_id}")
async def get_task_detail(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get task detail - accessible by assigned user or assigner"""
    try:
        task = db.query(Task).filter(Task.id == task_id).first()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        if task.assigned_to_id != current_user.id and task.assigned_by_id != current_user.id:
            raise HTTPException(status_code=403, detail="You don't have access to this task")
        
        assigned_by = db.query(User).filter(User.id == task.assigned_by_id).first()
        assigned_to = db.query(User).filter(User.id == task.assigned_to_id).first()
        
        return {
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "assigned_by_name": assigned_by.name if assigned_by else "Unknown",
            "assigned_by_nip": assigned_by.nip if assigned_by else "Unknown",
            "assigned_to_name": assigned_to.name if assigned_to else "Unknown",
            "assigned_to_nip": assigned_to.nip if assigned_to else "Unknown",
            "due_date": task.due_date.isoformat() if task.due_date else None,
            "start_date": task.start_date.isoformat() if task.start_date else None,
            "end_date": task.end_date.isoformat() if task.end_date else None,
            "status": task.status,
            "priority": task.priority,
            "notes": task.notes,
            "completion_notes": task.completion_notes,
            "created_at": task.created_at.isoformat(),
            "completed_at": task.completed_at.isoformat() if task.completed_at else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting task: {str(e)}")
