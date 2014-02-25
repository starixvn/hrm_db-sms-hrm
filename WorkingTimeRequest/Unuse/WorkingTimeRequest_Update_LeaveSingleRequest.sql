USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Insert]    Script Date: 2013-11-04 8:12:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_Update_LeaveSingleRequest]
	@RequestId bigint,
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@FromDate datetime=NULL, 
	@ToDate datetime=NULL, 
	@LeaveTypeID int=NULL, 
	@TotalDays numeric(5,1)=NULL, 

	@ModifiedDate datetime=NULL,
	@ModifiedBy int=NULL,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

	@RefNo nvarchar(200)='',

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: Update a Leave Single request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;

IF (@RequestType IN (6) AND 
	(@FromDate IS NULL OR @ToDate IS NULL OR @LeaveTypeID IS NULL 
		OR ISNULL(@TotalDays,0) < 0 )
	)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'Leave request has the invalid parameter'
	RETURN;
END

DECLARE @IsTopManager BIT
SELECT @IsTopManager = IsTopManager from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

DECLARE	@_FromDate NVARCHAR(100), @_ToDate NVARCHAR(100)

SELECT @_FromDate = CONVERT(VARCHAR(10),@fromDate,111) + ' 00:00:00',
		@_ToDate = CONVERT(VARCHAR(10),@toDate,111) + ' 00:00:00'

IF exists(select top 1 1 from dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner join dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
			where r.empid=@empid 
			AND r.RequestType=@RequestType
			AND r.RequestId <> @RequestId
			AND CurrentStatus in (1,2)
			AND (
					(@TotalDays >= 1 AND 
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)  
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)
						OR CONVERT(VARCHAR(10),@fromdate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR CONVERT(VARCHAR(10),@todate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays >= 1 AND
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)  
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN CONVERT(VARCHAR(10),@fromdate,111) AND CONVERT(VARCHAR(10),@todate,111)
						OR CONVERT(VARCHAR(10),@fromdate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR CONVERT(VARCHAR(10),@todate,111) BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays < 1 AND
						((fromdate BETWEEN @_FromDate AND @_ToDate) 
						OR (todate BETWEEN @_FromDate AND @_ToDate) 
						OR (@_FromDate BETWEEN fromdate AND todate) 
						OR (@_ToDate BETWEEN fromdate AND todate))
					)
				)
	) 
	OR
		(SELECT COUNT(1) FROM dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner join dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
			WHERE r.empid=@empid 
			AND r.RequestType=@RequestType
			AND CurrentStatus IN (1,2)
			AND @TotalDays < 1
			AND TotalDays = 0.5
			AND (fromdate BETWEEN @_FromDate AND @_ToDate)
		) >=2 
BEGIN
	SET @ErrCode = 107
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

-- check the total day is valid
BEGIN
	IF (@TotalDays < 1 AND DATEDIFF(d,@FromDate, @ToDate)<> 0 )
	BEGIN
		SET @ErrCode =109
		SET @ErrMsg = 'The total days is not correct'
		RETURN;
	END
	ELSE
	BEGIN
		IF (@TotalDays >= 1 AND 
			@TotalDays <> (SELECT COUNT(1) FROM dbo.EmployeeCalendar WITH(NOLOCK)
							WHERE EmpID= @EmpId AND WorkDate BETWEEN @_FromDate AND @_ToDate
							AND IsHoliday = 0 AND IsOffDay = 0 AND IsLeaveDay = 0)
			)
		BEGIN
			SET @ErrCode =110
			SET @ErrMsg = 'The total days is not correct'
			RETURN;
		END
	END
END

-- check the total day is not greater than annual leave balance
BEGIN
	IF (EXISTS(SELECT top 1 1 FROM dbo.LeaveType  WITH(NOLOCK) WHERE LeaveTypeID = @LeaveTypeID AND IsALDeduction = 1)
		AND @TotalDays > (SELECT AnnualLeaveBalance FROM EmployeeSummary  WITH(NOLOCK) WHERE EmpId = @EmpId)
	)		
	BEGIN
		SET @ErrCode =111
		SET @ErrMsg = 'You have not enough annual leave days to request'
		RETURN;
	END
	
END	
 
BEGIN TRY
	BEGIN TRANSACTION
		UPDATE WorkingTimeRequest WITH(ROWLOCK,UPDLOCK)
		SET 	
				Remark = @Remark,
				[CurrentStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
						WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
						WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
						ELSE 1 END,
				VerifierId = @VerifierId,
				[VerifiedStatus]=CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
				ApproverId = @ApproverId,
				[ApprovedStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
				HRId = @HRId,
				ModifiedBy = @ModifiedBy,
				ModifiedDate = @ModifiedDate
		WHERE RequestId = @RequestId
		
		UPDATE [dbo].[LeaveRequest] WITH(ROWLOCK,UPDLOCK)
		SET 
			[FromDate] = @FromDate
			,[ToDate] = @ToDate
			,[LeaveType] =@LeaveTypeID
			,[TotalDays] =@TotalDays
			,[RefNo] =@RefNo
		WHERE RequestId = @RequestId
		
		COMMIT TRANSACTION;
		SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = N'Update request failed.'
		ROLLBACK TRANSACTION;
END CATCH;

EXEC [WorkingTimeRequest_WriteHistory] @RequestId

SELECT @RequestId
SET @ErrCode = 0