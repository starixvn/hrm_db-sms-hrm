USE [HRM_SMS]
GO

/****** Object:  StoredProcedure [dbo].[Project_Insert]    Script Date: 5/9/2014 10:17:58 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Message_GetByEmployee]
	@EmployeeId INT,
	@EffectedDate DATETIME,
	@IsDisabled BIT = NULL
AS
/*
Created: 20140714@Quinn.Vo
Task: Get message by employee.
DB: NexEPA
Original: 

Revisions:  
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ms.MessageId,
		ms.[Subject],
		ms.[Contents],
		ms.[Category],
		ms.[FromDate],
		ms.[ToDate],
		ISNULL(mse.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS ms WITH (NOLOCK)
	INNER JOIN dbo.MessageGroup AS mg WITH (NOLOCK) ON ms.MessageId = mg.MessageId
	INNER JOIN dbo.Employee AS e WITH (NOLOCK) ON mg.GroupId = e.GroupId
	LEFT JOIN dbo.MessageEmployee AS mse WITH (NOLOCK) ON e.EmpId = mse.EmployeeId AND ms.MessageId = mse.MessageId
	WHERE e.EmpId = @EmployeeId 
		AND (mse.EmployeeId IS NULL OR (mse.EmployeeId IS NOT NULL AND mse.IsDisabled = 0))
		AND (ms.FromDate IS NULL OR ms.ToDate IS NULL OR (@EffectedDate BETWEEN ms.FromDate AND ms.ToDate))
	UNION
	SELECT m.MessageId,
		m.[Subject],
		m.[Contents],
		m.[Category],
		m.[FromDate],
		m.[ToDate],
		ISNULL(me.IsRead, 0) AS IsRead
	FROM dbo.[Message] AS m WITH (NOLOCK)
	INNER JOIN dbo.MessageEmployee AS me WITH (NOLOCK) ON m.MessageId = me.MessageId
	WHERE me.EmployeeId = @EmployeeId 
		AND (@IsDisabled IS NULL OR me.IsDisabled = @IsDisabled)
		AND (m.FromDate IS NULL OR m.ToDate IS NULL OR (@EffectedDate BETWEEN m.FromDate AND m.ToDate))
END
