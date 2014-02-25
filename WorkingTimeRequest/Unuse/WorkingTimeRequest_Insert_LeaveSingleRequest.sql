USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Insert]    Script Date: 2013-11-04 8:12:19 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_Insert_LeaveSingleRequest]
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@FromDate datetime=NULL, 
	@ToDate datetime=NULL, 
	@LeaveTypeID int=NULL, 
	@TotalDays numeric(5,1)=NULL, 

	@CreatedDate datetime=NULL,
	@CreatedBy int=NULL,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,

	@RefNo nvarchar(200)='',

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: insert a Leave Single request form
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

DECLARE	@_FromDate NVARCHAR(100), @_ToDate NVARCHAR(100)

SELECT @_FromDate = CONVERT(VARCHAR(10),@FromDate,111) + ' 00:00:00',
		@_ToDate = CONVERT(VARCHAR(10),@ToDate,111)+ ' 00:00:00'

IF (@RequestType = 6) AND 
	(exists(select top 1 1 from dbo.WorkingTimeRequest r WITH (NOLOCK)
					Inner join dbo.LeaveRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
			where r.empid=@empid 
			AND r.RequestType=@RequestType
			AND CurrentStatus in (1,2)
			AND (
					(@TotalDays >= 1 AND 
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN @_FromDate AND @_ToDate 
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN @_FromDate AND CONVERT(VARCHAR(10),@todate,111)
						OR @_FromDate BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR @_ToDate BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays >= 1 AND
						(CONVERT(VARCHAR(10),fromdate,111) BETWEEN @_FromDate AND @_ToDate 
						OR CONVERT(VARCHAR(10),todate,111) BETWEEN @_FromDate AND CONVERT(VARCHAR(10),@todate,111)
						OR @_FromDate BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111)
						OR @_ToDate BETWEEN CONVERT(VARCHAR(10),fromdate,111) AND CONVERT(VARCHAR(10),todate,111))
					)
					OR
					(
						@TotalDays < 1 AND TotalDays < 1 AND
						((fromdate BETWEEN @_fromdate AND @_todate) 
						OR (todate BETWEEN @_fromdate AND @_todate) 
						OR (@_fromdate BETWEEN fromdate AND todate) 
						OR (@_todate BETWEEN fromdate AND todate))
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
			AND (CONVERT(VARCHAR(10),fromdate,111) BETWEEN @_FromDate AND CONVERT(VARCHAR(10),@todate,111))
		) >=2 
	)
BEGIN
	SET @ErrCode = 107
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

-- check the total day is valid
IF ( @RequestType = 6)
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
							WHERE EmpID= @EmpId AND WorkDate BETWEEN @FromDate AND @ToDate
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
IF ( @RequestType = 6)
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

DECLARE @IsTopManager BIT
SELECT @IsTopManager = IsTopManager from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =112
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

EXEC [dbo].WorkingTimeRequest_GetNewRefNoByRequestType 
	@RefNo =@RefNo output,
	@RequestType =6
	

INSERT INTO dbo.WorkingTimeRequest
(	   [EmpId]
      ,[RequestType]
      ,[Remark]
      ,[CurrentStatus]
      ,[VerifierId]
      ,[ApproverId]
      ,[HRId]
      ,[VerifiedStatus]
      ,[ApprovedStatus]
      ,[HRStatus]
      ,[CreatedDate]
	  ,[CreatedBy]
)
VALUES
(
	@EmpId, 
	@RequestType,	
	@Remark,
	CASE WHEN @IsTopManager=1 AND @VerifierId IS NOT NULL THEN 1 
		WHEN @IsTopManager=1 AND @ApproverId IS NOT NULL THEN 2 
		WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 4 
		ELSE 1 END, -- pending [CurrentStatus] as default
	@VerifierId,
	@ApproverId,
	@HRId,
	CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
	CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
	1, -- pending [HRStatus] as default
	@CreatedDate, 
	@CreatedBy
)

DECLARE @RequestId bigint

SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)

INSERT INTO [dbo].[LeaveRequest]
			([RequestId]
			,[EmpId]
			,[FromDate]
			,[ToDate]
			,[LeaveType]
			,[TotalDays]
			,[RefNo])
		VALUES
			(@RequestId,
			@EmpId,
			@FromDate,
			@ToDate,
			@LeaveTypeID,
			@TotalDays,
			@RefNo
			)

 
EXEC [WorkingTimeRequest_WriteHistory] @RequestId

SET @ErrCode = 0

SELECT @RequestId
