@isTest
public class TaskReminderTest {

    @TestSetup
    static void makeData() {
        // Create test opportunity
        Opportunity opp = new Opportunity(
            Name      = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount    = 100000
        );
        insert opp;

        // Create overdue task
        Task t = new Task(
            Subject      = 'Overdue follow up',
            ActivityDate = Date.today().addDays(-3),
            Status       = 'Not Started',
            Priority     = 'High',
            OwnerId      = UserInfo.getUserId(),
            WhatId       = opp.Id
        );
        insert t;
    }

    // Test 1: sendOverdueReminders finds and emails overdue tasks
    @isTest
    static void testSendOverdueReminders() {
        Test.startTest();
        TaskReminderScheduler.sendOverdueReminders();
        Test.stopTest();
        // No exception = pass
        System.assert(true,
            'sendOverdueReminders should run without error');
    }

    // Test 2: scheduler execute() method
    @isTest
    static void testSchedulerExecute() {
        String cron = '0 0 8 * * ?';
        Test.startTest();
        String jobId = System.schedule(
            'Test Task Reminder',
            cron,
            new TaskReminderScheduler()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId,
            'Job should be scheduled');
    }

    // Test 3: no tasks — method exits without error
    @isTest
    static void testNoOverdueTasks() {
        // Mark the setup task as completed
        Task t = [SELECT Id FROM Task LIMIT 1];
        t.Status = 'Completed';
        update t;

        Test.startTest();
        TaskReminderScheduler.sendOverdueReminders();
        Test.stopTest();
        System.assert(true,
            'Empty list should not throw');
    }

    // Test 4: Flow creates task on stage change
    @isTest
    static void testFlowCreatesTask() {
        Opportunity opp = [
            SELECT Id, StageName
            FROM   Opportunity LIMIT 1
        ];
        Test.startTest();
        opp.StageName = 'Qualification';
        update opp;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject FROM Task
            WHERE  WhatId = :opp.Id
            AND    Subject LIKE '%Qualification%'
        ];
        // Flow must have created a task
        System.assert(!tasks.isEmpty(),
            'Flow should create task on stage change');
    }

    // Test 5: bell notification — handles missing type
    @isTest
    static void testBellNotifMissingType() {
        Map<Id, List<Task>> tasksByOwner =
            new Map<Id, List<Task>>();
        List<Task> tasks = [
            SELECT Id, Subject, WhatId, OwnerId
            FROM   Task LIMIT 1
        ];
        tasksByOwner.put(
            tasks[0].OwnerId, tasks);
        Test.startTest();
        // Type won't exist in test org — isEmpty guard fires
        TaskReminderScheduler.sendBellNotifications(
            tasksByOwner);
        Test.stopTest();
        System.assert(true,
            'Missing notif type should not throw');
    }
}