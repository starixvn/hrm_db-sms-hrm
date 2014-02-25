USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WorkingTimeRequest_Insert_ChangeShift]
	@EmpId int, 
	@RequestType smallint=5,	
	@Remark nvarchar(2000),				
	@FromDate datetime, 
	@ToDate datetime, 

	@CreatedDate datetime,
	@CreatedBy int,

	@VerifierId  int=NULL,
    @ApproverId  int=NULL,
    @HRId  int=NULL,	

	@ListDetail XML ,

	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT	
AS
/*
Created: Tom.Vo@2013-11-04
Task: insert Change Shift request form
DB: HRM_SMS
Original: 

Revisions:    
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

IF (@RequestType NOT IN (5) )
BEGIN
	SET @ErrCode =104
	SET @ErrMsg = 'Change-shift request has the invalid parameter'
	RETURN;
END

IF (Datediff(dd,@FromDate,@ToDate)>14)
BEGIN
	SET @ErrCode =105
	SET @ErrMsg = 'Change-shift request has the invalid parameter'
	RETURN;
END

DECLARE @IsTopManager BIT,@IsLocal  BIT
SELECT @IsTopManager = IsTopManager,@IsLocal=IsLocal from dbo.EmployeeSummary WITH(NOLOCK) WHERE EmpId = @EmpId

IF ((@ApproverId IS NULL OR @VerifierId IS NULL) AND @IsTopManager = 0)
BEGIN
	SET @ErrCode =106
	SET @ErrMsg = 'Invalid parameter'
	RETURN;
END

-- check if there is another request in the same date
IF (@RequestType IN (5) AND 
	exists(select top 1 1 from dbo.WorkingTimeRequest r WITH(NOLOCK)
					Inner join dbo.ChangeShiftRequest l WITH(NOLOCK) ON r.RequestId = l.RequestId
		where r.empid=@empid 
			and RequestType=@RequestType
			and CurrentStatus in  (1,2,3,4,6)
			and datediff(d, l.fromdate, @FromDate ) = 0
	)
)
BEGIN
	SET @ErrCode =107
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
		SELECT @ErrCode = 100, @ErrMsg = N'Create change shift request for an employee failed.'
		Return
END CATCH;

IF @EmpId <> @CreatedBy
BEGIN
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @EmpId
		AND sp.EmpId = @CreatedBy
		AND sp.ActionType = 5
		AND sp.RequestType in (5)
		)
	BEGIN
		SET @ErrCode = 108
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
		AND sp.RequestType in (5)
		)
	BEGIN
		SET @ErrCode = 109
		SET @ErrMsg = 'invalid parameter verifierid.'
		RETURN;
	END
	IF NOT EXISTS (SELECT TOP 1 1
	FROM [dbo].[EmployeeSupervisor] sp WITH(NOLOCK)
	WHERE sp.OwnerId = @ApproverId
		AND sp.EmpId = @EmpId
		AND sp.ActionType = 3
		AND sp.RequestType in (5)
		)
	BEGIN
		SET @ErrCode = 110
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
	CASE WHEN @IsTopManager=1 AND @VerifierId IS NULL THEN 2 ELSE 1 END, -- pending [VerifiedStatus] as default
	CASE WHEN @IsTopManager=1 AND @ApproverId IS NULL THEN 2 ELSE 1 END, -- pending [ApprovedStatus] as default
	1, -- pending [HRStatus] as default
	@CreatedDate, 
	@CreatedBy
)

DECLARE @RequestId bigint

SELECT @RequestId = cast(SCOPE_IDENTITY() as bigint)

INSERT INTO [dbo].[ChangeShiftRequest]
           ([RequestId]
           ,[EmpId]
           ,[FromDate]
           ,[ToDate])
     VALUES
           (@RequestId
           ,@EmpId
           ,@FromDate
           ,@ToDate)

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
				@ApprovedDate =@CreatedDate ,
				@RoleID =3,
				@ErrCode = @ErrCode  OUTPUT,
				@ErrMsg  = @ErrMsg   OUTPUT
END

EXEC [WorkingTimeRequest_WriteHistory] @RequestId

 IF @@ERROR <> 0 
	BEGIN
		DELETE  dbo.WorkingTimeRequest WHERE RequestId = @RequestId
		DELETE  dbo.[ChangeShiftRequest] WHERE RequestId = @RequestId
		DELETE  dbo.[ChangeShiftRequestDetail] WHERE RequestId = @RequestId

		SELECT @ErrCode = 101, @ErrMsg = N'Create change shift request for an employee failed.'
	END
ELSE 
	SELECT @ErrCode=0,@ErrMsg=''

SET @ErrCode = 0

DROP TABLE #ChangeShiftDetail

SELECT @RequestId