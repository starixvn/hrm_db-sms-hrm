USE HRM_SMS
GO
/****** Object:  StoredProcedure [dbo].[WorkingTimeRequest_Update]    Script Date: 2013-11-04 3:37:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_Update_ChangeShiftRequest]
	@RequestId bigint,
	@EmpId int, 
	@RequestType smallint=5,	
	@Remark nvarchar(2000),				
	@FromDate datetime, 
	@ToDate datetime, 

	@ModifiedDate datetime,
	@ModifiedBy int,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,	

	@ListDetail XML,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: update a request form
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
Param's Explanation:
	@ListDetail:
		<Requests>
		 <Request>
			<OnDate>20130101</OnDate>
			<FromShift>1</FromShift>
			<ToShift>2</ToShift>
			<Remark>ABC</Remark>
		  </Request>
		  <Request>
			<OnDate>20130102</OnDate>
			<FromShift>1</FromShift>
			<ToShift>22</ToShift>
			<Remark>ABC</Remark>
		  </Request>
		  <Request>
			<OnDate>20130103</OnDate>
			<FromShift>1</FromShift>
			<ToShift>13</ToShift>
			<Remark>DEF</Remark>
		  </Request>
		</Requests>
*/

SET NOCOUNT ON;

IF EXISTS(SELECT TOP 1 1
	FROM dbo.WorkingTimeRequest r WITH(NOLOCK) 	
		WHERE r.RequestId = @RequestId
			AND r.CurrentStatus <> 1)
BEGIN
	SET @ErrCode =100
	SET @ErrMsg = 'Process awaiting approval. You could not edit this request.'
	RETURN;
END

IF (Datediff(dd,@FromDate,@ToDate)>14)
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'Change-shift request has the invalid parameter'
	RETURN;
END

DECLARE @IsTopManager BIT 
SELECT @IsTopManager = IsTopManager from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

-- check if there is another request in the same date
IF (@RequestType IN (1,2,5) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
					Inner join dbo.ChangeShiftRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.empid=@empid 
			and RequestType=@RequestType
			and r.RequestId <>@RequestId
			and CurrentStatus in  (1,2,3,4,6)
			and datediff(d, l.fromdate, @FromDate ) = 0
	)
)
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = 'There is another request in the same date'
	RETURN;
END
CREATE TABLE #ChangeShiftDetail (OnDate DateTime,FromShift	INT,ToShift	INT,Remark varchar(1000))
DECLARE @DocHandler INT
BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @ListDetail
	INSERT INTO #ChangeShiftDetail (OnDate,FromShift,ToShift,Remark)
	SELECT OnDate,FromShift,ToShift,Remark
	FROM OPENXML (@DocHandler, '/Requests/Request',2) 
	WITH (	OnDate	DateTime,
			FromShift	INT, 
			ToShift	INT,
			Remark	varchar(2000)) AS Data

	EXEC sp_xml_removedocument @DocHandler

END TRY
BEGIN CATCH
		--select ERROR_MESSAGE ( )  		
		SELECT @ErrCode = 100, @ErrMsg = N'Create change shift request for an employee failed.'
		Return
END CATCH;

IF @EmpId <> @ModifiedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @ModifiedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (5)
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
		AND sp.RequestType = 5	
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
		AND sp.RequestType = 5	
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter ApproverId.'
		RETURN;
	END
END

-- cut off time
IF (@RequestType IN (5))
BEGIN
	SET @fromdate = CONVERT(VARCHAR(10),@fromdate,111)
	IF (@todate IS NOT NULL)
		SET @todate = CONVERT(VARCHAR(10),@todate,111)
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

		UPDATE [dbo].[ChangeShiftRequest]WITH(ROWLOCK,UPDLOCK)
				  SET [FromDate] = @FromDate
				   , [ToDate] =@ToDate
		WHERE RequestId = @RequestId

		DELETE [dbo].[ChangeShiftRequestDetail]
		WHERE RequestId = @RequestId

		INSERT INTO [dbo].[ChangeShiftRequestDetail]
				   ([EmpId]
				   ,[OnDate]
				   ,[RequestId]
				   ,[FromShift]
				   ,[ToShift]
				   ,[Remark])
		SELECT @EmpId , rd.OnDate, @RequestId RequestId ,rd.FromShift,rd.ToShift,rd.Remark 
		FROM #ChangeShiftDetail rd

		IF (@ApproverId IS NULL AND @VerifierId IS NULL AND @IsTopManager = 1)
		BEGIN
				EXEC [dbo].[WorkingTimeRequest_ApproveRequest_5]
						@RequestID =@RequestID,
						@EmpID =@EmpID,
						@ApprovedBy =@EmpID,
						@ApprovedDate =@ModifiedDate ,
						@RoleID =3,
						@ErrCode = @ErrCode  OUTPUT,
						@ErrMsg  = @ErrMsg   OUTPUT
		END

		EXEC [WorkingTimeRequest_WriteHistory] @RequestId

		 IF @@ERROR <> 0 
			BEGIN
				SELECT @ErrCode = 101, @ErrMsg = N'Create change shift request for an employee failed.'
			END
		ELSE 
			SELECT @ErrCode=0,@ErrMsg=''

		COMMIT TRANSACTION;
		SELECT @ErrCode=0,@ErrCode=''
END TRY
BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = N'Delete request failed.'
		ROLLBACK TRANSACTION;
END CATCH;
DROP TABLE #ChangeShiftDetail