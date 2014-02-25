--USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[WorkingTimeRequest_Update_KeepInViewRequest]
	@RequestId bigint,
	@EmpId int, 
	@RequestType smallint,	

	@Remark nvarchar(2000)=NULL,	
	@OnDate datetime=NULL, 
	@IsHalfDay BIT=NULL, 
	@ShiftId numeric(5,1)=NULL, 
	@FromTime datetime=NULL,
	@ToTime datetime=NULL,	
	@ExpExchangeDay decimal(18,2)=NULL,

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
Created: Tom.Vo@2013-11-11
Task: Update a Keep in view request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
*/
SET NOCOUNT ON;
SET @RefNo = ISNULL(@RefNo,'')
IF (@RequestType IN (7) AND (( @FromTime IS NULL AND @ToTime IS NULL AND @IsHalfDay =1 ) OR @IsHalfDay IS NULL ) ) 
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Keep In request has the invalid parameter'
	RETURN;
END

IF EXISTS(SELECT 	TOP 1 1
	FROM dbo.WorkingTimeRequest r WITH(NOLOCK) 	
		WHERE r.RequestId = @RequestId
			AND r.CurrentStatus <> 1)
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Process awaiting approval. You could not edit this request.'
	RETURN;
END

IF (@RequestType IN (7) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
				Inner join dbo.[KeepInViewRequest] l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.empid=@empid 
			AND r.RequestType=@RequestType
			AND r.CurrentStatus in  (1,2,3,4,6)
			AND r.RequestId <> @RequestId
			AND @OnDate BETWEEN l.FromDate AND l.ToDate 
		)
	)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'There is another request in the same range'
	RETURN;
END

IF (NOT EXISTS (SELECT TOP 1 1 FROM dbo.EmployeeCalendar WITH(NOLOCK) WHERE WorkDate = @OnDate AND EmpId = @EmpId AND (IsHoliday = 1 OR IsOffDay = 1)))
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = CONVERT(NVARCHAR(100),@OnDate,106 ) + '  not off date or holiday '
	RETURN
END

DECLARE @IsTopManager BIT
SELECT @IsTopManager = IsTopManager from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =102
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

IF @EmpId <> @ModifiedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @ModifiedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (7)
		)
	BEGIN
		SET @ErrCode = 107
		SET @ErrMsg = 'You could not permision on this request.'
		RETURN;
	END
END

IF @IsTopManager = 0
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @VerifierId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 2
		AND sp.RequestType = 7	
		)
	BEGIN
		SET @ErrCode = 108
		SET @ErrMsg = 'invalid parameter verifierid.'
		RETURN;
	END
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @ApproverId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 3
		AND sp.RequestType = 7	
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
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
				[VerifiedStatus]=CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
				ApproverId = @ApproverId,
				[ApprovedStatus]=CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
				HRId = @HRId,
				ModifiedBy = @ModifiedBy,
				ModifiedDate = @ModifiedDate
		WHERE RequestId = @RequestId
		
		UPDATE [dbo].[KeepInViewRequest] WITH(ROWLOCK,UPDLOCK)
		SET 
			[FromDate] = @OnDate
			,[ToDate] = @OnDate
			,[IsHalfDay] =@IsHalfDay
			,[ShiftId] =@ShiftId
			,[FromTime] =@FromTime
			,[ToTime] =@ToTime
			,[ExpExchangeDay] =@ExpExchangeDay
			--,[RefNo]=@RefNo
		WHERE RequestId = @RequestId
 
		IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
		BEGIN
				EXEC [dbo].[WorkingTimeRequest_ApproveRequest_7]
						@RequestID =@RequestID,
						@EmpID =@EmpID,
						@ApprovedBy =@EmpID,
						@ApprovedDate =@ModifiedDate ,
						@RoleID =3,
						@ErrCode = @ErrCode  OUTPUT,
						@ErrMsg  = @ErrMsg   OUTPUT
		END

		EXEC [WorkingTimeRequest_WriteHistory] @RequestId
			
		COMMIT TRANSACTION;
		SELECT @ErrCode=0,@ErrCode=''

END TRY
BEGIN CATCH
	
		SELECT @ErrCode = 101, @ErrMsg = N'Update request failed.'
		ROLLBACK TRANSACTION;

		Return
END CATCH;

SELECT @RequestId
SELECT @ErrCode = 0,@ErrMsg=''