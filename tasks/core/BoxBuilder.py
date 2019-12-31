import logging

class BoxBuilder(object):
    def __init__(self, ctx, box_name, provider, steps, since):
        self.ctx = ctx
        self.box_name = box_name
        self.provider = provider
        self.steps = steps
        self.since = since

        self.real_steps = self._calculate_steps()

    def _calculate_steps(self):
        """
        Calculate the real_step list based on either
        - nothing: all steps
        - steps: the steps wanted by the user
        - since: all the steps since that step number

        :rtype: Array of step numbers - string
        """
        logging.debug("Calculating steps from user input")
        # Raise an exception when the steps and since are both defined
        if self.steps and self.since:
            raise ValueError("Found value for steps and since. Use either steps or since")

        # Case for a since.
        if self.since:
            return self._provide_steps_since(self.since)
        # Case when user provided the steps
        elif self.steps:
            return self.steps
        # Case when all steps needs to be build
        else:
            return self._provide_steps_since('1')

    def _provide_steps_since(self, since):
        """
        Extract the total number of steps for the box (by listing the dir).
        The list is then generated from the since to that total
        :param since: the step since
        :type since: str
        :rtype array of steps - str 
        """
        json_steps = self.ctx.run(
            "ls env/{}/*.json".format(self.box_name),
            hide="out"
        )
        nb_tot_steps = len(json_steps.stdout.split('\n'))
        return [str(i) for i in range(int(since), nb_tot_steps)]

    def build(self,):
        for step in self.real_steps:
            logging.debug("Building step number: {}".format(step))

            filename = self.ctx.run(
                "ls env/{}/{}-*.json | xargs basename".format(self.box_name, step),
                hide="out",
            ).stdout.strip()

            cmd = ("CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=logs/{}-{}.log && " +
		        "packer build -force -only={}-{} -on-error=abort env/{}/{}").format(
                    self.box_name,
                    self.provider,
                    self.box_name,
                    self.provider,
                    self.box_name,
                    filename
                )
            
            logging.debug("Running: {}".format(cmd))
            self.ctx.run(cmd)


