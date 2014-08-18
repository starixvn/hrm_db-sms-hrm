USE [HRM_SMS]
GO

/****** Object:  Table [dbo].[GroupSupervisor]    Script Date: 7/23/2014 8:59:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP TABLE [dbo].[GroupSupervisor]
CREATE TABLE [dbo].[GroupSupervisor](
	[OwnerId] [int] NOT NULL,
	[GroupId] [int] NOT NULL,
	[ActionType] [tinyint] NOT NULL,
	[RequestType] [tinyint] NOT NULL,
	[ModifiedBy] [int] NULL,
	[ModifiedDate] [datetime] NULL
CONSTRAINT [PK_GroupSupervisor] PRIMARY KEY CLUSTERED 
(
	[OwnerId] ASC,
	[GroupId] ASC,
	[ActionType] ASC,
	[RequestType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [Employee]
) ON [Employee]

GO

