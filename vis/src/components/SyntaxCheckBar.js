import React from 'react';
import Box from '@mui/material/Box';
import Stepper from '@mui/material/Stepper';
import Step from '@mui/material/Step';
import StepLabel from '@mui/material/StepButton';
import Typography from '@mui/material/Typography';
import { red, orange, green } from '@mui/material/colors';
import ErrorIcon from '@mui/icons-material/Error';
import PendingIcon from '@mui/icons-material/Pending';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';

const steps = ['Signature', 'Formula', 'Trace'];

export default function StatusBar({ checkedInputs }) {

  return (
    <Box display="flex"
         justifyContent="center"
         alignItems="center"
         sx={{ width: '100%', height: '100%' }}>
      <Stepper nonLinear>
        {steps.map((label, index) => {
          const labelProps = {};

          switch (checkedInputs[index]) {
          case "ok":
            labelProps.icon = (<CheckCircleIcon fontSize="large" />);
            labelProps.optional = (
              <Typography variant="caption" color={green[600]}>
                valid
              </Typography>
            );
            break;
          case "error":
            labelProps.icon = (<ErrorIcon fontSize="large" />);
            labelProps.optional = (
              <Typography variant="caption" color={red[900]}>
                invalid
              </Typography>
            );
            break;
          case "empty":
            labelProps.icon = (<PendingIcon fontSize="large" />);
            labelProps.optional = (
              <Typography variant="caption" color={orange[600]}>
                empty
              </Typography>
            );
            break;
          }

          return (
            <Step active={checkedInputs[index] === "ok"} expanded
                  key={label}
                  /* completed={checkedInputs[index] === "ok"} */
                  sx={{
                    '& .MuiStepLabel-root .Mui-completed': {
                      color: 'black', // circle's color
                    },
                    '& .MuiStepLabel-label.Mui-completed.MuiStepLabel-alternativeLabel':
                    {
                      color: 'black',
                    },
                    '& .MuiStepLabel-root .Mui-active': {
                      color: 'black', // circle's color
                    },
                    '& .MuiStepLabel-label.Mui-active.MuiStepLabel-alternativeLabel':
                    {
                      color: 'common.white',
                    },
                    '& .MuiStepLabel-root .Mui-active .MuiStepIcon-text': {
                      fill: 'black', // circle's number
                    },
                  }}>
              <StepLabel {...labelProps}>
                {label}
              </StepLabel>
            </Step>
          );
        })}
      </Stepper>
    </Box>
  );
}
