from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, date
import os
from pathlib import Path

from ..database import get_db
from ..models.user import User
from ..models.absensi import Leave, LeaveQuota, LeaveType, LeaveCategory, LeaveStatus
from ..services.leave_quota_service import LeaveQuotaService
from ..services.holiday_service import HolidayService
from ..middleware.auth_middleware import get_current_user
from ..config import UPLOAD_DIR

router = APIRouter()

# Ensure upload directory exists
leave_uploads = Path(UPLOAD_DIR) / "leave_attachments"
leave_uploads.mkdir(parents=True, exist_ok=True)


@router.get("/quota")
async def get_leave_quota(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get leave quota for current user"""
    try:
        quota = LeaveQuotaService.get_or_create_quota(db, current_user.id)
        
        return {
            "year": quota.year,
            "total_quota": quota.total_quota,
            "used_quota": quota.used_quota,
            "remaining_quota": quota.remaining_quota
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting quota: {str(e)}")


@router.get("/supervisors")
async def get_supervisors(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get list of supervisors/managers for leave approval"""
    try:
        # Get all users who can be supervisors (kepala/manager roles)
        supervisors = db.query(User).filter(
            User.is_active == True,
            User.id != current_user.id,  # Exclude current user
        ).all()
        
        result = []
        for supervisor in supervisors:
            result.append({
                "id": supervisor.id,
                "name": supervisor.name,
                "nip": supervisor.nip,
                "department": supervisor.department,
            })
        
        return {"supervisors": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting supervisors: {str(e)}")


@router.get("/list")
async def get_leaves(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all leaves for current user"""
    try:
        leaves = db.query(Leave).filter(
            Leave.user_id == current_user.id
        ).order_by(Leave.created_at.desc()).all()
        
        result = []
        for leave in leaves:
            result.append({
                "id": leave.id,
                "type": leave.type.value,
                "category": leave.category.value,
                "start_date": leave.start_date.isoformat(),
                "end_date": leave.end_date.isoformat(),
                "total_days": leave.total_days,
                "reason": leave.reason,
                "status": leave.status.value,
                "attachment_path": leave.attachment_path,
                "approval_level_1_by": leave.approval_level_1_by,
                "approval_level_1_at": leave.approval_level_1_at.isoformat() if leave.approval_level_1_at else None,
                "approval_level_1_notes": leave.approval_level_1_notes,
                "approval_level_2_by": leave.approval_level_2_by,
                "approval_level_2_at": leave.approval_level_2_at.isoformat() if leave.approval_level_2_at else None,
                "approval_level_2_notes": leave.approval_level_2_notes,
                "created_at": leave.created_at.isoformat(),
            })
        
        return {"leaves": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting leaves: {str(e)}")


@router.post("/submit")
async def submit_leave(
    type: str = Form(...),
    category: str = Form(...),
    start_date: str = Form(...),
    end_date: str = Form(...),
    reason: str = Form(...),
    supervisor_id: Optional[str] = Form(None),
    attachment: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Submit a new leave request"""
    try:
        # Validate supervisor if provided
        if supervisor_id:
            supervisor = db.query(User).filter(User.id == supervisor_id).first()
            if not supervisor:
                raise HTTPException(status_code=400, detail="Atasan tidak ditemukan")
        
        # Parse leave type and category
        try:
            leave_type = LeaveType(type)
            leave_category = LeaveCategory(category)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid leave type or category")
        
        # Parse dates
        try:
            start = datetime.fromisoformat(start_date.replace('Z', '+00:00')).date()
            end = datetime.fromisoformat(end_date.replace('Z', '+00:00')).date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format")
        
        # Validate date range
        if end < start:
            raise HTTPException(status_code=400, detail="End date must be after start date")
        
        # Calculate working days (excluding weekends and holidays)
        total_days = LeaveQuotaService.calculate_working_days(start, end)
        
        if total_days == 0:
            raise HTTPException(
                status_code=400, 
                detail="Selected dates contain no working days (only weekends/holidays)"
            )
        
        # Check if quota needs to be deducted
        should_deduct = (
            leave_category == LeaveCategory.CUTI_TAHUNAN or 
            leave_category == LeaveCategory.SAKIT_TANPA_SURAT
        )
        
        if should_deduct:
            # Check quota availability
            # NOTE: No employment duration validation - users can use CUTI immediately
            quota = LeaveQuotaService.get_or_create_quota(db, current_user.id)
            if quota.remaining_quota < total_days:
                raise HTTPException(
                    status_code=400, 
                    detail=f"Insufficient leave quota. Available: {quota.remaining_quota} days, Required: {total_days} days"
                )
        
        # Handle attachment if provided
        attachment_path = None
        if attachment:
            # Validate file size (max 5MB)
            content = await attachment.read()
            if len(content) > 5 * 1024 * 1024:
                raise HTTPException(status_code=400, detail="File size exceeds 5MB")
            
            # Save file
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"{current_user.id}_{timestamp}_{attachment.filename}"
            file_path = leave_uploads / filename
            
            with open(file_path, "wb") as f:
                f.write(content)
            
            attachment_path = str(file_path.relative_to(UPLOAD_DIR))
        
        # Validate attachment for sakit dengan surat
        if leave_category == LeaveCategory.SAKIT_DENGAN_SURAT and not attachment_path:
            raise HTTPException(status_code=400, detail="Attachment is required for sick leave with letter")
        
        # Create leave record
        new_leave = Leave(
            user_id=current_user.id,
            type=leave_type,
            category=leave_category,
            start_date=start,
            end_date=end,
            total_days=total_days,
            reason=reason.strip(),
            attachment_path=attachment_path,
            supervisor_id=supervisor_id,  # Add supervisor_id
            status=LeaveStatus.PENDING
        )
        
        db.add(new_leave)
        db.flush()
        
        # Deduct quota if applicable (will be refunded if rejected)
        if should_deduct:
            service.deduct_quota(current_user.id, total_days)
        
        db.commit()
        db.refresh(new_leave)
        
        # Get holidays in the range for info
        holidays_in_range = HolidayService.get_holidays_for_range(start, end)
        
        return {
            "message": "Leave request submitted successfully",
            "leave_id": new_leave.id,
            "total_days": total_days,
            "quota_deducted": should_deduct,
            "holidays_excluded": len(holidays_in_range),
            "info": f"Working days only. Weekends and {len(holidays_in_range)} public holidays are automatically excluded."
        }
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error submitting leave: {str(e)}")


@router.post("/{leave_id}/approve")
async def approve_leave(
    leave_id: int,
    level: int = Form(...),  # 1 for supervisor, 2 for HR
    notes: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Approve a leave request (supervisor or HR)"""
    try:
        leave = db.query(Leave).filter(Leave.id == leave_id).first()
        if not leave:
            raise HTTPException(status_code=404, detail="Leave not found")
        
        if leave.status != LeaveStatus.PENDING:
            raise HTTPException(status_code=400, detail="Leave is not pending approval")
        
        from ..models.absensi import get_jakarta_time
        now = get_jakarta_time()
        
        if level == 1:
            # Supervisor approval
            leave.approval_level_1_by = current_user.id
            leave.approval_level_1_at = now
            leave.approval_level_1_notes = notes
        elif level == 2:
            # HR approval
            if not leave.approval_level_1_at:
                raise HTTPException(status_code=400, detail="Supervisor approval required first")
            
            leave.approval_level_2_by = current_user.id
            leave.approval_level_2_at = now
            leave.approval_level_2_notes = notes
            leave.status = LeaveStatus.APPROVED
        else:
            raise HTTPException(status_code=400, detail="Invalid approval level")
        
        db.commit()
        
        return {"message": f"Leave approved at level {level}"}
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error approving leave: {str(e)}")


@router.post("/{leave_id}/reject")
async def reject_leave(
    leave_id: int,
    notes: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reject a leave request"""
    try:
        leave = db.query(Leave).filter(Leave.id == leave_id).first()
        if not leave:
            raise HTTPException(status_code=404, detail="Leave not found")
        
        if leave.status != LeaveStatus.PENDING:
            raise HTTPException(status_code=400, detail="Leave is not pending approval")
        
        # Refund quota if it was deducted
        should_refund = (
            leave.category == LeaveCategory.CUTI_TAHUNAN or 
            leave.category == LeaveCategory.SAKIT_TANPA_SURAT
        )
        
        if should_refund:
            LeaveQuotaService.restore_quota(db, leave.user_id, leave.total_days)
        
        leave.status = LeaveStatus.REJECTED
        leave.approval_level_1_notes = notes
        
        db.commit()
        
        return {"message": "Leave rejected", "quota_refunded": should_refund}
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error rejecting leave: {str(e)}")
