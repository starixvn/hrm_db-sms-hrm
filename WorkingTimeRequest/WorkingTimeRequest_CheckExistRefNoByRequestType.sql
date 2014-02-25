USE HRM_SMS
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].WorkingTimeRequest_CheckExistRefNoByRequestType
	@isExist BIT=NULL output,
	@RefNo NVARCHAR(100),
	@RequestType INT
	
AS
/*
Created: Tom.Vo@2013-11-05
Task: Get New RefNo From Request Type
DB: HRM_SMS
Original: 

Revisions:    
Param's Explanation:
	
*/
SET NOCOUNT ON;

SET @isExist = 0

IF @RequestType IN (1,2)
	IF  exists(
		SELECT TOP 1 1
			FROM [dbo].LeaveRequest r WITH (NOLOCK) 
				INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
					ON r.RequestId = wr.RequestId
				WHERE r.RefNo= @RefNo AND wr.RequestType in (1,2)
				)
		SET @isExist = 1
ELSE IF @RequestType IN (3,4)
		IF  exists(
			SELECT TOP 1 1
				FROM [dbo].[InOutRequest] r WITH (NOLOCK)
					INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
							ON r.RequestId = wr.RequestId
					WHERE r.RefNo= @RefNo AND wr.RequestType in (3,4)
					)
			SET @isExist = 1
ELSE IF @RequestType IN (5)
		SELECT @RefNo = ''
ELSE IF @RequestType IN (6)
			IF  exists(
				SELECT TOP 1 1
				FROM [dbo].LeaveRequest r WITH (NOLOCK) 
					INNER JOIN [dbo].WorkingTimeRequest wr WITH (NOLOCK) 
						ON r.RequestId = wr.RequestId
					WHERE r.RefNo= @RefNo AND wr.RequestType in (6)
					)
				SET @isExist = 1
  